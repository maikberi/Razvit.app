import request from 'supertest';
import { randomUUID } from 'crypto';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { authHeaderForUser } from './testAuth';

const app = createApp();

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE foods, meals, nutrition_targets, water_entries RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

function userHeader(userId: string) {
  return authHeaderForUser(userId);
}

async function createFood(overrides: Record<string, unknown> = {}) {
  const res = await request(app)
    .post('/api/v1/foods')
    .send({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0, ...overrides });
  return res.body.data as { id: string };
}

describe('Meal API', () => {
  it('без авторизации — 401', async () => {
    const res = await request(app).get('/api/v1/meals');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('GET /meals создаёт 4 приёма пищи (breakfast/lunch/dinner/snack) на дату, если их ещё нет', async () => {
    const user = randomUUID();
    const res = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });

    expect(res.status).toBe(200);
    expect(res.body.data.meals.map((m: { type: string }) => m.type)).toEqual(['breakfast', 'lunch', 'dinner', 'snack']);
    expect(res.body.data.meals.every((m: { items: unknown[] }) => m.items.length === 0)).toBe(true);
  });

  it('повторный GET на ту же дату не плодит дубли приёмов пищи', async () => {
    const user = randomUUID();
    await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    const res = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    expect(res.body.data.meals).toHaveLength(4);
  });

  it('добавляет продукт по foodId и правильно считает нутриенты (курица 200г -> 330 ккал/62г белка)', async () => {
    const user = randomUUID();
    const chicken = await createFood();
    const day = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    const breakfastId = day.body.data.meals[0].id;

    const res = await request(app)
      .post(`/api/v1/meals/${breakfastId}/items`)
      .set(userHeader(user))
      .send({ foodId: chicken.id, grams: 200 });

    expect(res.status).toBe(201);
    expect(res.body.data.calories).toBe(330);
    expect(res.body.data.protein).toBe(62);
    expect(res.body.data.name).toBe('Куриная грудка');
  });

  it('добавляет ручной ввод (без foodId) с собственными нутриентами', async () => {
    const user = randomUUID();
    const day = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    const mealId = day.body.data.meals[0].id;

    const res = await request(app)
      .post(`/api/v1/meals/${mealId}/items`)
      .set(userHeader(user))
      .send({ name: 'Домашний салат', nutrients: { calories: 80, protein: 2, fat: 5, carbohydrates: 6 }, grams: 150 });

    expect(res.status).toBe(201);
    expect(res.body.data.name).toBe('Домашний салат');
    expect(res.body.data.calories).toBe(120); // 80*1.5
  });

  it('итоги приёма пищи — точная сумма нескольких продуктов (не задвоенная)', async () => {
    const user = randomUUID();
    const chicken = await createFood({ name: 'Курица' });
    const rice = await createFood({ name: 'Рис', calories: 112, protein: 2.6, fat: 0.9, carbohydrates: 23 });
    const day = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    const mealId = day.body.data.meals[1].id; // lunch

    await request(app).post(`/api/v1/meals/${mealId}/items`).set(userHeader(user)).send({ foodId: chicken.id, grams: 150 });
    await request(app).post(`/api/v1/meals/${mealId}/items`).set(userHeader(user)).send({ foodId: rice.id, grams: 100 });

    const after = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    const lunch = after.body.data.meals[1];
    // 165*1.5=247.5 + 112 = 359.5 -> round 360
    expect(lunch.calories).toBe(360);
    expect(lunch.items).toHaveLength(2);
  });

  it('404 при добавлении в несуществующий приём пищи', async () => {
    const user = randomUUID();
    const chicken = await createFood();
    const res = await request(app)
      .post('/api/v1/meals/00000000-0000-0000-0000-000000000000/items')
      .set(userHeader(user))
      .send({ foodId: chicken.id, grams: 100 });
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('MEAL_NOT_FOUND');
  });

  it('403, если пытаться добавить продукт в чужой приём пищи', async () => {
    const owner = randomUUID();
    const intruder = randomUUID();
    const chicken = await createFood();
    const day = await request(app).get('/api/v1/meals').set(userHeader(owner)).query({ date: '2026-01-15' });
    const mealId = day.body.data.meals[0].id;

    const res = await request(app)
      .post(`/api/v1/meals/${mealId}/items`)
      .set(userHeader(intruder))
      .send({ foodId: chicken.id, grams: 100 });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('обновляет граммовку продукта (PATCH /meal-items/:id)', async () => {
    const user = randomUUID();
    const chicken = await createFood();
    const day = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    const mealId = day.body.data.meals[0].id;
    const added = await request(app).post(`/api/v1/meals/${mealId}/items`).set(userHeader(user)).send({ foodId: chicken.id, grams: 100 });

    const patch = await request(app).patch(`/api/v1/meal-items/${added.body.data.id}`).set(userHeader(user)).send({ grams: 200 });
    expect(patch.status).toBe(204);

    const after = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    expect(after.body.data.meals[0].items[0].calories).toBe(330);
  });

  it('удаляет продукт из приёма пищи (DELETE /meal-items/:id)', async () => {
    const user = randomUUID();
    const chicken = await createFood();
    const day = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    const mealId = day.body.data.meals[0].id;
    const added = await request(app).post(`/api/v1/meals/${mealId}/items`).set(userHeader(user)).send({ foodId: chicken.id, grams: 100 });

    const del = await request(app).delete(`/api/v1/meal-items/${added.body.data.id}`).set(userHeader(user));
    expect(del.status).toBe(204);

    const after = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    expect(after.body.data.meals[0].items).toHaveLength(0);
  });

  it('добавление продукта из каталога попадает в Recent Foods', async () => {
    const user = randomUUID();
    const chicken = await createFood();
    const day = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    await request(app).post(`/api/v1/meals/${day.body.data.meals[0].id}/items`).set(userHeader(user)).send({ foodId: chicken.id, grams: 100 });

    const recent = await request(app).get('/api/v1/foods/recent').set(userHeader(user));
    expect(recent.status).toBe(200);
    expect(recent.body.data.map((f: { id: string }) => f.id)).toContain(chicken.id);
  });
});

describe('Nutrition daily/targets/water API', () => {
  it('GET /nutrition/targets создаёт цели по умолчанию при первом обращении', async () => {
    const user = randomUUID();
    const res = await request(app).get('/api/v1/nutrition/targets').set(userHeader(user));
    expect(res.status).toBe(200);
    expect(res.body.data.calorieGoal).toBeGreaterThan(0);
  });

  it('PUT /nutrition/targets обновляет цели', async () => {
    const user = randomUUID();
    const res = await request(app)
      .put('/api/v1/nutrition/targets')
      .set(userHeader(user))
      .send({ calorieGoal: 2000, proteinGoal: 140, fatGoal: 60, carbsGoal: 220, waterGoalMl: 2000 });
    expect(res.status).toBe(200);
    expect(res.body.data.calorieGoal).toBe(2000);

    const after = await request(app).get('/api/v1/nutrition/targets').set(userHeader(user));
    expect(after.body.data.calorieGoal).toBe(2000);
  });

  it('POST /nutrition/water добавляет воду, GET суммирует за день', async () => {
    const user = randomUUID();
    await request(app).post('/api/v1/nutrition/water').set(userHeader(user)).send({ amountMl: 250 });
    const res = await request(app).post('/api/v1/nutrition/water').set(userHeader(user)).send({ amountMl: 250 });
    expect(res.status).toBe(201);
    expect(res.body.data.consumedMl).toBe(500);

    const get = await request(app).get('/api/v1/nutrition/water').set(userHeader(user));
    expect(get.body.data.consumedMl).toBe(500);
  });

  it('DELETE /nutrition/water/last убирает последнюю запись', async () => {
    const user = randomUUID();
    await request(app).post('/api/v1/nutrition/water').set(userHeader(user)).send({ amountMl: 250 });
    await request(app).post('/api/v1/nutrition/water').set(userHeader(user)).send({ amountMl: 250 });
    const res = await request(app).delete('/api/v1/nutrition/water/last').set(userHeader(user));
    expect(res.body.data.consumedMl).toBe(250);
  });

  it('GET /nutrition/daily собирает приёмы пищи, цели, воду и остаток одним ответом', async () => {
    const user = randomUUID();
    const chicken = await createFood();
    await request(app)
      .put('/api/v1/nutrition/targets')
      .set(userHeader(user))
      .send({ calorieGoal: 2000, proteinGoal: 150, fatGoal: 60, carbsGoal: 200, waterGoalMl: 2000 });

    const day = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date: '2026-01-15' });
    await request(app).post(`/api/v1/meals/${day.body.data.meals[0].id}/items`).set(userHeader(user)).send({ foodId: chicken.id, grams: 200 });
    await request(app).post('/api/v1/nutrition/water').set(userHeader(user)).send({ amountMl: 500, date: '2026-01-15' });

    const res = await request(app).get('/api/v1/nutrition/daily').set(userHeader(user)).query({ date: '2026-01-15' });

    expect(res.status).toBe(200);
    expect(res.body.data.consumed.calories).toBe(330);
    expect(res.body.data.targets.calorieGoal).toBe(2000);
    expect(res.body.data.remaining.calories).toBe(1670);
    expect(res.body.data.progressPercent).toBe(17); // round(330/2000*100)
    expect(res.body.data.water).toEqual({ consumedMl: 500, goalMl: 2000 });
    expect(res.body.data.meals).toHaveLength(4);
  });

  it('пустой день -> consumed = 0, remaining = goal', async () => {
    const user = randomUUID();
    await request(app)
      .put('/api/v1/nutrition/targets')
      .set(userHeader(user))
      .send({ calorieGoal: 2000, proteinGoal: 150, fatGoal: 60, carbsGoal: 200, waterGoalMl: 2000 });

    const res = await request(app).get('/api/v1/nutrition/daily').set(userHeader(user)).query({ date: '2026-02-01' });
    expect(res.body.data.consumed.calories).toBe(0);
    expect(res.body.data.remaining.calories).toBe(2000);
    expect(res.body.data.progressPercent).toBe(0);
  });
});
