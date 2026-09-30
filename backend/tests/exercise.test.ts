import request from 'supertest';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { newTestUser } from './testAuth';

const app = createApp();

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  // Каталог упражнений (exercises) — справочные данные из миграции
  // 018_exercise_seed.sql, как reference-продукты в foods (013_reference_foods.sql):
  // не трогаем таблицу целиком, только пользовательские избранные.
  await pool.query('TRUNCATE exercise_favorites RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

describe('Exercise Database API', () => {
  it('GET /exercises — отдаёт каталог с пагинацией (100 упражнений из сида)', async () => {
    const res = await request(app).get('/api/v1/exercises');
    expect(res.status).toBe(200);
    expect(res.body.meta.total).toBe(100);
    expect(res.body.data.length).toBe(20); // perPage по умолчанию
    expect(res.body.data[0].gifUrl).toMatch(/^https:\/\//);
  });

  it('GET /exercises?muscleGroup=chest — фильтрует по группе мышц', async () => {
    const res = await request(app).get('/api/v1/exercises').query({ muscleGroup: 'chest', perPage: 100 });
    expect(res.status).toBe(200);
    expect(res.body.meta.total).toBe(13);
    expect(res.body.data.every((e: { primaryMuscle: string }) => e.primaryMuscle === 'chest')).toBe(true);
  });

  it('GET /exercises?q= — ищет по названию', async () => {
    const res = await request(app).get('/api/v1/exercises').query({ q: 'приседания' });
    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeGreaterThan(0);
    for (const item of res.body.data) {
      expect(item.name.toLowerCase()).toContain('приседания');
    }
  });

  it('GET /exercises?muscleGroup=неверное — 422', async () => {
    const res = await request(app).get('/api/v1/exercises').query({ muscleGroup: 'invalid' });
    expect(res.status).toBe(422);
  });

  it('GET /exercises/:id — отдаёт упражнение по id', async () => {
    const list = await request(app).get('/api/v1/exercises').query({ q: 'Подтягивания широким хватом' });
    const id = list.body.data[0].id;

    const res = await request(app).get(`/api/v1/exercises/${id}`);
    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe('Подтягивания широким хватом');
    expect(res.body.data.difficulty).toBe('advanced');
    expect(Array.isArray(res.body.data.instructions)).toBe(true);
    expect(res.body.data.instructions.length).toBeGreaterThan(0);
  });

  it('GET /exercises/:id — 404 для несуществующего id', async () => {
    const res = await request(app).get('/api/v1/exercises/00000000-0000-0000-0000-000000000000');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('EXERCISE_NOT_FOUND');
  });

  it('POST /exercises/:id/favorite без авторизации — 401', async () => {
    const list = await request(app).get('/api/v1/exercises').query({ perPage: 1 });
    const id = list.body.data[0].id;
    const res = await request(app).post(`/api/v1/exercises/${id}/favorite`);
    expect(res.status).toBe(401);
  });

  it('добавляет и убирает упражнение из избранного', async () => {
    const { header } = newTestUser();
    const list = await request(app).get('/api/v1/exercises').query({ perPage: 1 });
    const id = list.body.data[0].id;

    const add = await request(app).post(`/api/v1/exercises/${id}/favorite`).set(header);
    expect(add.status).toBe(204);

    const favorites = await request(app).get('/api/v1/exercises/favorites').set(header);
    expect(favorites.status).toBe(200);
    expect(favorites.body.data).toHaveLength(1);
    expect(favorites.body.data[0].id).toBe(id);
    expect(favorites.body.data[0].isFavorite).toBe(true);

    const remove = await request(app).delete(`/api/v1/exercises/${id}/favorite`).set(header);
    expect(remove.status).toBe(204);

    const afterRemove = await request(app).get('/api/v1/exercises/favorites').set(header);
    expect(afterRemove.body.data).toHaveLength(0);
  });

  it('избранное одного пользователя не видно другому (SECURITY)', async () => {
    const userA = newTestUser();
    const userB = newTestUser();
    const list = await request(app).get('/api/v1/exercises').query({ perPage: 1 });
    const id = list.body.data[0].id;

    await request(app).post(`/api/v1/exercises/${id}/favorite`).set(userA.header);

    const bFavorites = await request(app).get('/api/v1/exercises/favorites').set(userB.header);
    expect(bFavorites.body.data).toHaveLength(0);
  });

  it('повторное добавление в избранное — идемпотентно (ON CONFLICT DO NOTHING)', async () => {
    const { header } = newTestUser();
    const list = await request(app).get('/api/v1/exercises').query({ perPage: 1 });
    const id = list.body.data[0].id;

    await request(app).post(`/api/v1/exercises/${id}/favorite`).set(header);
    const second = await request(app).post(`/api/v1/exercises/${id}/favorite`).set(header);
    expect(second.status).toBe(204);

    const favorites = await request(app).get('/api/v1/exercises/favorites').set(header);
    expect(favorites.body.data).toHaveLength(1);
  });
});
