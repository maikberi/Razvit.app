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
  await pool.query('TRUNCATE weight_entries RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

describe('Weight tracking API', () => {
  it('POST /weight-entries без авторизации — 401', async () => {
    const res = await request(app).post('/api/v1/weight-entries').send({ weightKg: 80 });
    expect(res.status).toBe(401);
  });

  it('добавляет запись веса и возвращает её в списке', async () => {
    const { header } = newTestUser();
    const add = await request(app).post('/api/v1/weight-entries').set(header).send({ weightKg: 82.5 });
    expect(add.status).toBe(201);
    expect(add.body.data.weightKg).toBe(82.5);
    expect(typeof add.body.data.loggedAt).toBe('string');

    const list = await request(app).get('/api/v1/weight-entries').set(header);
    expect(list.status).toBe(200);
    expect(list.body.data).toHaveLength(1);
    expect(list.body.data[0].weightKg).toBe(82.5);
  });

  it('список отсортирован по дате по возрастанию (для графика)', async () => {
    const { header } = newTestUser();
    await request(app).post('/api/v1/weight-entries').set(header).send({ weightKg: 80, loggedAt: '2026-01-01T00:00:00Z' });
    await request(app).post('/api/v1/weight-entries').set(header).send({ weightKg: 78, loggedAt: '2026-02-01T00:00:00Z' });

    const list = await request(app).get('/api/v1/weight-entries').set(header);
    expect(list.body.data.map((e: { weightKg: number }) => e.weightKg)).toEqual([80, 78]);
  });

  it('POST /weight-entries с некорректным весом — 422', async () => {
    const { header } = newTestUser();
    const res = await request(app).post('/api/v1/weight-entries').set(header).send({ weightKg: -5 });
    expect(res.status).toBe(422);
  });

  it('удаляет запись веса', async () => {
    const { header } = newTestUser();
    const add = await request(app).post('/api/v1/weight-entries').set(header).send({ weightKg: 80 });
    const id = add.body.data.id;

    const del = await request(app).delete(`/api/v1/weight-entries/${id}`).set(header);
    expect(del.status).toBe(204);

    const list = await request(app).get('/api/v1/weight-entries').set(header);
    expect(list.body.data).toHaveLength(0);
  });

  it('удалить чужую запись веса нельзя (SECURITY)', async () => {
    const userA = newTestUser();
    const userB = newTestUser();
    const add = await request(app).post('/api/v1/weight-entries').set(userA.header).send({ weightKg: 80 });
    const id = add.body.data.id;

    const del = await request(app).delete(`/api/v1/weight-entries/${id}`).set(userB.header);
    expect(del.status).toBe(404);

    const list = await request(app).get('/api/v1/weight-entries').set(userA.header);
    expect(list.body.data).toHaveLength(1);
  });

  it('история веса одного пользователя не видна другому (SECURITY)', async () => {
    const userA = newTestUser();
    const userB = newTestUser();
    await request(app).post('/api/v1/weight-entries').set(userA.header).send({ weightKg: 80 });

    const bList = await request(app).get('/api/v1/weight-entries').set(userB.header);
    expect(bList.body.data).toHaveLength(0);
  });
});
