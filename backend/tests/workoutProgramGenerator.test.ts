import request from 'supertest';
import { randomUUID } from 'crypto';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { authHeaderForUser } from './testAuth';

const app = createApp();

function userHeader(userId: string) {
  return authHeaderForUser(userId);
}

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE workout_programs, workout_profiles, nutrition_profiles RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

describe('GET/PUT /workout-profile', () => {
  it('GET — по умолчанию все поля пустые', async () => {
    const user = randomUUID();
    const res = await request(app).get('/api/v1/workout-profile').set(userHeader(user));
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ experience: null, place: null, equipment: [], workoutsPerWeek: null, duration: null });
  });

  it('PUT — частичные обновления накапливаются, не затирают уже заполненные поля', async () => {
    const user = randomUUID();
    await request(app).put('/api/v1/workout-profile').set(userHeader(user)).send({ experience: 'beginner', place: 'home' });
    const res = await request(app)
      .put('/api/v1/workout-profile')
      .set(userHeader(user))
      .send({ equipment: ['dumbbells', 'bands'], workoutsPerWeek: 3, duration: 'medium' });

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({
      experience: 'beginner',
      place: 'home',
      equipment: ['dumbbells', 'bands'],
      workoutsPerWeek: 3,
      duration: 'medium',
    });
  });
});

describe('POST /workout-programs/generate', () => {
  it('без анкеты — 422 WORKOUT_PROFILE_INCOMPLETE', async () => {
    const user = randomUUID();
    const res = await request(app).post('/api/v1/workout-programs/generate').set(userHeader(user));
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('WORKOUT_PROFILE_INCOMPLETE');
    expect(res.body.error.details.missingFields).toEqual(
      expect.arrayContaining(['experience', 'place', 'workoutsPerWeek', 'duration']),
    );
  });

  it('анкета тренировок заполнена, но нет цели (nutrition_profiles.goal) — тоже 422', async () => {
    const user = randomUUID();
    await request(app)
      .put('/api/v1/workout-profile')
      .set(userHeader(user))
      .send({ experience: 'beginner', place: 'gym', workoutsPerWeek: 3, duration: 'medium' });

    const res = await request(app).post('/api/v1/workout-programs/generate').set(userHeader(user));
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('WORKOUT_PROFILE_INCOMPLETE');
    expect(res.body.error.details.missingFields).toEqual(['goal']);
  });

  it('полная анкета (зал, 3 тренировки в неделю) — собирает и сохраняет полноценную программу из реального каталога упражнений', async () => {
    const user = randomUUID();
    await request(app)
      .put('/api/v1/workout-profile')
      .set(userHeader(user))
      .send({ experience: 'beginner', place: 'gym', workoutsPerWeek: 3, duration: 'medium' });
    await request(app).put('/api/v1/nutrition/profile').set(userHeader(user)).send({ goal: 'gain_muscle' });

    const res = await request(app).post('/api/v1/workout-programs/generate').set(userHeader(user));
    expect(res.status).toBe(201);
    expect(res.body.data.goal).toBe('mass'); // gain_muscle -> mass
    expect(res.body.data.level).toBe('beginner');
    expect(res.body.data.isCustom).toBe(true);
    expect(res.body.data.days).toHaveLength(3); // 3 тренировки в неделю -> 3 full-body дня
    for (const day of res.body.data.days) {
      expect(day.exercises.length).toBeGreaterThan(0);
      for (const ex of day.exercises) {
        expect(ex.sets).toBe(4); // gain_muscle scheme
        expect(ex.repsLabel).toBe('8-12');
      }
    }

    // Сгенерированная программа реально сохранена — видна в GET /workout-programs,
    // как и вручную созданные (create_program_screen.dart использует тот же список).
    const list = await request(app).get('/api/v1/workout-programs').set(userHeader(user));
    expect(list.status).toBe(200);
    expect(list.body.data).toHaveLength(1);
    expect(list.body.data[0].id).toBe(res.body.data.id);
  });

  it('дома без оборудования, 5 тренировок в неделю, продвинутый — собирает push/pull/legs/upper/lower из подходящих под уровень или запасных упражнений', async () => {
    const user = randomUUID();
    await request(app)
      .put('/api/v1/workout-profile')
      .set(userHeader(user))
      .send({ experience: 'advanced', place: 'home', equipment: ['none'], workoutsPerWeek: 5, duration: 'long' });
    await request(app).put('/api/v1/nutrition/profile').set(userHeader(user)).send({ goal: 'lose_weight' });

    const res = await request(app).post('/api/v1/workout-programs/generate').set(userHeader(user));
    expect(res.status).toBe(201);
    expect(res.body.data.goal).toBe('loss');
    expect(res.body.data.days).toHaveLength(5);
    // Никакой день не остаётся пустым, даже с самым тонким пулом (без оборудования).
    for (const day of res.body.data.days) {
      expect(day.exercises.length).toBeGreaterThan(0);
    }
  });
});
