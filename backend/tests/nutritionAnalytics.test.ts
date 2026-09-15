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

function daysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString().slice(0, 10);
}

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE foods, meals, nutrition_targets, water_entries RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

async function createFood(overrides: Record<string, unknown> = {}) {
  const res = await request(app)
    .post('/api/v1/foods')
    .send({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0, ...overrides });
  return res.body.data as { id: string };
}

async function logFood(user: string, date: string, foodId: string, grams: number) {
  const day = await request(app).get('/api/v1/meals').set(userHeader(user)).query({ date });
  await request(app).post(`/api/v1/meals/${day.body.data.meals[0].id}/items`).set(userHeader(user)).send({ foodId, grams });
}

describe('GET /nutrition/analytics (агрегированная статистика — backend считает всё)', () => {
  it('без авторизации — 401', async () => {
    const res = await request(app).get('/api/v1/nutrition/analytics');
    expect(res.status).toBe(401);
  });

  it('пустой период (нет записей) — нулевые средние, но валидная структура ответа для empty state', async () => {
    const user = randomUUID();
    const res = await request(app).get('/api/v1/nutrition/analytics').set(userHeader(user)).query({ period: '7d' });

    expect(res.status).toBe(200);
    expect(res.body.data.period).toBe('7d');
    expect(res.body.data.days).toHaveLength(7);
    expect(res.body.data.loggedDays).toBe(0);
    expect(res.body.data.averages).toEqual({ calories: 0, protein: 0, fat: 0, carbohydrates: 0, waterMl: 0 });
    expect(res.body.data.goalAdherencePercent).toBe(0);
    expect(res.body.data.daysOnTarget).toBe(0);
    expect(res.body.data.totalDays).toBe(7);
  });

  it('period=30d/90d возвращают правильную длину окна', async () => {
    const user = randomUUID();
    const res30 = await request(app).get('/api/v1/nutrition/analytics').set(userHeader(user)).query({ period: '30d' });
    expect(res30.body.data.days).toHaveLength(30);
    const res90 = await request(app).get('/api/v1/nutrition/analytics').set(userHeader(user)).query({ period: '90d' });
    expect(res90.body.data.days).toHaveLength(90);
  });

  it('считает среднее только по дням с записями, а не по всем дням периода', async () => {
    const user = randomUUID();
    const chicken = await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });

    // Логируем еду только за 2 из 7 дней — 200г и 100г.
    await logFood(user, daysAgo(0), chicken.id, 200); // 330 ккал
    await logFood(user, daysAgo(1), chicken.id, 100); // 165 ккал

    const res = await request(app).get('/api/v1/nutrition/analytics').set(userHeader(user)).query({ period: '7d' });

    expect(res.body.data.loggedDays).toBe(2);
    // (330 + 165) / 2 = 247.5 -> округление до целого = 248 (как и в остальном проекте)
    expect(res.body.data.averages.calories).toBe(248);
    expect(res.body.data.totalDays).toBe(7);
  });

  it('вода учитывается по дням и попадает в averages.waterMl', async () => {
    const user = randomUUID();
    await request(app).post('/api/v1/nutrition/water').set(userHeader(user)).send({ amountMl: 500, date: daysAgo(0) });
    await request(app).post('/api/v1/nutrition/water').set(userHeader(user)).send({ amountMl: 1000, date: daysAgo(1) });

    const res = await request(app).get('/api/v1/nutrition/analytics').set(userHeader(user)).query({ period: '7d' });
    expect(res.body.data.loggedDays).toBe(2);
    expect(res.body.data.averages.waterMl).toBe(750);
    const todayEntry = res.body.data.days.find((d: { date: string }) => d.date === daysAgo(0));
    expect(todayEntry.waterMl).toBe(500);
    expect(todayEntry.hasEntries).toBe(true);
  });

  it('goal adherence: день в пределах ±10% от calorieGoal считается onTarget', async () => {
    const user = randomUUID();
    await request(app)
      .put('/api/v1/nutrition/targets')
      .set(userHeader(user))
      .send({ calorieGoal: 2000, proteinGoal: 150, fatGoal: 60, carbsGoal: 200, waterGoalMl: 2000 });

    const food = await createFood({ name: 'Тестовый продукт', calories: 2000, protein: 150, fat: 60, carbohydrates: 200 });
    // day0: 2000 ккал -> ровно в цель; day1: 3000 ккал -> сильно мимо (>10%)
    await logFood(user, daysAgo(0), food.id, 100);
    await logFood(user, daysAgo(1), food.id, 150);

    const res = await request(app).get('/api/v1/nutrition/analytics').set(userHeader(user)).query({ period: '7d' });
    expect(res.body.data.loggedDays).toBe(2);
    expect(res.body.data.daysOnTarget).toBe(1);
    expect(res.body.data.goalAdherencePercent).toBe(50);
  });

  it('невалидный period — 422', async () => {
    const user = randomUUID();
    const res = await request(app).get('/api/v1/nutrition/analytics').set(userHeader(user)).query({ period: '14d' });
    expect(res.status).toBe(422);
  });
});
