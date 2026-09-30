import request from 'supertest';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';

const app = createApp();

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE users RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

function uniqueEmail() {
  return `user-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
}

describe('Auth API', () => {
  it('POST /auth/register создаёт пользователя и возвращает токен', async () => {
    const email = uniqueEmail();
    const res = await request(app).post('/api/v1/auth/register').send({ email, password: 'supersecret1', name: 'Михаил' });

    expect(res.status).toBe(201);
    expect(res.body.data.token).toEqual(expect.any(String));
    expect(res.body.data.user).toMatchObject({ email, name: 'Михаил' });
    expect(res.body.data.user.id).toEqual(expect.any(String));
  });

  it('POST /auth/register — email уже занят — 409', async () => {
    const email = uniqueEmail();
    await request(app).post('/api/v1/auth/register').send({ email, password: 'supersecret1', name: 'Михаил' });

    const res = await request(app).post('/api/v1/auth/register').send({ email, password: 'anotherpass1', name: 'Другой' });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('EMAIL_ALREADY_REGISTERED');
  });

  it('POST /auth/register — некорректные данные — 422', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: 'not-an-email', password: '123', name: '' });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('POST /auth/login с верным паролем возвращает токен', async () => {
    const email = uniqueEmail();
    await request(app).post('/api/v1/auth/register').send({ email, password: 'supersecret1', name: 'Михаил' });

    const res = await request(app).post('/api/v1/auth/login').send({ email, password: 'supersecret1' });

    expect(res.status).toBe(200);
    expect(res.body.data.token).toEqual(expect.any(String));
    expect(res.body.data.user.email).toBe(email);
  });

  it('POST /auth/login с неверным паролем — 401', async () => {
    const email = uniqueEmail();
    await request(app).post('/api/v1/auth/register').send({ email, password: 'supersecret1', name: 'Михаил' });

    const res = await request(app).post('/api/v1/auth/login').send({ email, password: 'wrongpassword' });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('POST /auth/login с неизвестным email — 401', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ email: uniqueEmail(), password: 'whatever1' });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('GET /auth/me без токена — 401', async () => {
    const res = await request(app).get('/api/v1/auth/me');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('GET /auth/me с невалидным токеном — 401', async () => {
    const res = await request(app).get('/api/v1/auth/me').set('Authorization', 'Bearer garbage-token');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('GET /auth/me с валидным токеном возвращает текущего пользователя', async () => {
    const email = uniqueEmail();
    const registerRes = await request(app)
      .post('/api/v1/auth/register')
      .send({ email, password: 'supersecret1', name: 'Михаил' });
    const token = registerRes.body.data.token as string;

    const res = await request(app).get('/api/v1/auth/me').set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ email, name: 'Михаил' });
  });

  it('PATCH /auth/me без токена — 401', async () => {
    const res = await request(app).patch('/api/v1/auth/me').send({ name: 'Новое имя' });
    expect(res.status).toBe(401);
  });

  it('PATCH /auth/me — обновляет имя/фамилию/никнейм/фото', async () => {
    const email = uniqueEmail();
    const registerRes = await request(app).post('/api/v1/auth/register').send({ email, password: 'supersecret1', name: 'Михаил' });
    const token = registerRes.body.data.token as string;

    const avatar = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    const res = await request(app)
      .patch('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Михаил Обновлённый', lastName: 'Иванов', nickname: 'misha', avatarUrl: avatar });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ name: 'Михаил Обновлённый', lastName: 'Иванов', nickname: 'misha', avatarUrl: avatar });

    const me = await request(app).get('/api/v1/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.body.data).toMatchObject({ name: 'Михаил Обновлённый', lastName: 'Иванов', nickname: 'misha' });
  });

  it('PATCH /auth/me — частичное обновление не трогает уже сохранённые поля', async () => {
    const email = uniqueEmail();
    const registerRes = await request(app).post('/api/v1/auth/register').send({ email, password: 'supersecret1', name: 'Михаил' });
    const token = registerRes.body.data.token as string;

    await request(app).patch('/api/v1/auth/me').set('Authorization', `Bearer ${token}`).send({ nickname: 'misha' });
    const res = await request(app).patch('/api/v1/auth/me').set('Authorization', `Bearer ${token}`).send({ lastName: 'Иванов' });

    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ name: 'Михаил', lastName: 'Иванов', nickname: 'misha' });
  });

  it('PATCH /auth/me — явный null очищает поле (например, убрать фото)', async () => {
    const email = uniqueEmail();
    const registerRes = await request(app).post('/api/v1/auth/register').send({ email, password: 'supersecret1', name: 'Михаил' });
    const token = registerRes.body.data.token as string;

    await request(app).patch('/api/v1/auth/me').set('Authorization', `Bearer ${token}`).send({ nickname: 'misha' });
    const res = await request(app).patch('/api/v1/auth/me').set('Authorization', `Bearer ${token}`).send({ nickname: null });

    expect(res.status).toBe(200);
    expect(res.body.data.nickname).toBeNull();
  });

  it('PATCH /auth/me — avatarUrl не data:image — 422', async () => {
    const email = uniqueEmail();
    const registerRes = await request(app).post('/api/v1/auth/register').send({ email, password: 'supersecret1', name: 'Михаил' });
    const token = registerRes.body.data.token as string;

    const res = await request(app).patch('/api/v1/auth/me').set('Authorization', `Bearer ${token}`).send({ avatarUrl: 'https://evil.example.com/x.png' });
    expect(res.status).toBe(422);
  });
});
