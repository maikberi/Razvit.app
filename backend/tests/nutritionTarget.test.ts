import request from 'supertest';
import { randomUUID } from 'crypto';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { authHeaderForUser } from './testAuth';
import { IncompleteNutritionProfileError, NutritionTargetService } from '../src/modules/nutrition/nutritionTarget.service';

const app = createApp();

function userHeader(userId: string) {
  return authHeaderForUser(userId);
}

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE nutrition_targets, nutrition_profiles RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

describe('NutritionTargetService (расчёт целей из профиля — отдельно от Nutrition Engine)', () => {
  const service = new NutritionTargetService();

  it('мужчина, 30 лет, 180см, 80кг, умеренная активность, поддержание — считает BMR/TDEE/макросы по Mifflin-St Jeor', () => {
    const result = service.computeTargets({
      sex: 'male',
      age: 30,
      heightCm: 180,
      weightKg: 80,
      activityLevel: 'moderate',
      goal: 'maintain',
    });

    // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 1780; TDEE = 1780*1.55 = 2759
    expect(result.calorieGoal).toBe(2759);
    expect(result.proteinGoal).toBe(128); // 80 * 1.6 г/кг
    expect(result.fatGoal).toBe(77); // round(2759*0.25/9)
    expect(result.carbsGoal).toBe(389); // остаток калорий / 4
    expect(result.waterGoalMl).toBe(3240); // 80*33 + moderate(индекс 2)*300
  });

  it('женщина, 25 лет, 165см, 60кг, малоподвижная, похудение — калорийный дефицит и повышенный белок', () => {
    const result = service.computeTargets({
      sex: 'female',
      age: 25,
      heightCm: 165,
      weightKg: 60,
      activityLevel: 'sedentary',
      goal: 'lose_weight',
    });

    // BMR = 10*60 + 6.25*165 - 5*25 - 161 = 1345.25; TDEE = 1345.25*1.2 = 1614.3; *0.8 = 1291.44 -> 1291
    expect(result.calorieGoal).toBe(1291);
    expect(result.proteinGoal).toBe(120); // 60 * 2.0 г/кг (сохранение мышц при дефиците)
    expect(result.waterGoalMl).toBe(1980); // 60*33 + sedentary(индекс 0)*300
  });

  it('калории никогда не опускаются ниже безопасного минимума, даже при экстремальном дефиците на маленьком весе', () => {
    const result = service.computeTargets({
      sex: 'female',
      age: 60,
      heightCm: 150,
      weightKg: 45,
      activityLevel: 'sedentary',
      goal: 'lose_weight',
    });
    expect(result.calorieGoal).toBeGreaterThanOrEqual(1200);
  });

  it('toCompleteProfile бросает IncompleteNutritionProfileError со списком отсутствующих полей', () => {
    expect(() => service.toCompleteProfile(null)).toThrow(IncompleteNutritionProfileError);

    let caught: unknown;
    try {
      service.toCompleteProfile(null);
    } catch (err) {
      caught = err;
    }
    expect(caught).toBeInstanceOf(IncompleteNutritionProfileError);
    expect((caught as IncompleteNutritionProfileError).missingFields).toEqual(
      expect.arrayContaining(['sex', 'age', 'heightCm', 'weightKg', 'activityLevel', 'goal']),
    );
  });
});

describe('POST /nutrition/profile, /nutrition/targets/generate (HTTP)', () => {
  it('GET /nutrition/profile — по умолчанию все поля null', async () => {
    const user = randomUUID();
    const res = await request(app).get('/api/v1/nutrition/profile').set(userHeader(user));
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ sex: null, age: null, heightCm: null, weightKg: null, activityLevel: null, goal: null });
  });

  it('PUT /nutrition/profile — частичные обновления накапливаются (не затирают уже заполненные поля)', async () => {
    const user = randomUUID();
    await request(app).put('/api/v1/nutrition/profile').set(userHeader(user)).send({ sex: 'male', age: 28 });
    const res = await request(app)
      .put('/api/v1/nutrition/profile')
      .set(userHeader(user))
      .send({ heightCm: 178, weightKg: 75, activityLevel: 'active', goal: 'gain_muscle' });

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({
      sex: 'male',
      age: 28,
      heightCm: 178,
      weightKg: 75,
      activityLevel: 'active',
      goal: 'gain_muscle',
    });
  });

  it('POST /nutrition/targets/generate с неполным профилем — 422 NUTRITION_PROFILE_INCOMPLETE', async () => {
    const user = randomUUID();
    await request(app).put('/api/v1/nutrition/profile').set(userHeader(user)).send({ sex: 'male', age: 28 });

    const res = await request(app).post('/api/v1/nutrition/targets/generate').set(userHeader(user));
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('NUTRITION_PROFILE_INCOMPLETE');
    expect(res.body.error.details.missingFields).toEqual(expect.arrayContaining(['heightCm', 'weightKg', 'activityLevel', 'goal']));
  });

  it('POST /nutrition/targets/generate с полным профилем — считает и сохраняет цели, дальше их можно редактировать вручную', async () => {
    const user = randomUUID();
    await request(app)
      .put('/api/v1/nutrition/profile')
      .set(userHeader(user))
      .send({ sex: 'male', age: 30, heightCm: 180, weightKg: 80, activityLevel: 'moderate', goal: 'maintain' });

    const generated = await request(app).post('/api/v1/nutrition/targets/generate').set(userHeader(user));
    expect(generated.status).toBe(200);
    expect(generated.body.data.calorieGoal).toBe(2759);

    const persisted = await request(app).get('/api/v1/nutrition/targets').set(userHeader(user));
    expect(persisted.body.data.calorieGoal).toBe(2759);

    // Сгенерированные цели остаются изменяемыми пользователем вручную (PUT /nutrition/targets).
    const edited = await request(app)
      .put('/api/v1/nutrition/targets')
      .set(userHeader(user))
      .send({ calorieGoal: 2500, proteinGoal: 130, fatGoal: 70, carbsGoal: 300, waterGoalMl: 3000 });
    expect(edited.status).toBe(200);
    expect(edited.body.data.calorieGoal).toBe(2500);
  });
});
