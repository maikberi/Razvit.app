import express from 'express';
import request from 'supertest';
import rateLimit from 'express-rate-limit';

// authRateLimiter/aiRateLimiter (src/middleware/rateLimiter.ts) отключены
// в NODE_ENV=test (см. skipInTests) — иначе весь остальной набор тестов,
// который намеренно бьёт /auth/register и /foods по многу раз за один
// прогон, начал бы падать на лимите. Поэтому здесь проверяется тот же
// самый механизм (express-rate-limit + наш JSON-обработчик 429) на
// изолированном мини-приложении, где лимит специально не выключен —
// вместо переключения общего NODE_ENV посреди тестового прогона.
function buildTestApp() {
  const app = express();
  const limiter = rateLimit({
    windowMs: 60_000,
    limit: 2,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (_req, res) => {
      res.status(429).json({ error: { code: 'RATE_LIMITED', message: 'Слишком много запросов, попробуй позже' } });
    },
  });
  app.get('/ping', limiter, (_req, res) => res.status(200).json({ ok: true }));
  return app;
}

describe('Rate limiting middleware (express-rate-limit + JSON 429)', () => {
  it('пропускает запросы в пределах лимита', async () => {
    const app = buildTestApp();
    const first = await request(app).get('/ping');
    const second = await request(app).get('/ping');
    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
  });

  it('после превышения лимита — 429 с понятным JSON-телом ошибки', async () => {
    const app = buildTestApp();
    await request(app).get('/ping');
    await request(app).get('/ping');
    const third = await request(app).get('/ping');

    expect(third.status).toBe(429);
    expect(third.body.error.code).toBe('RATE_LIMITED');
    expect(third.body.error.message).toBeTruthy();
  });

  it('лимит считается отдельно на каждый инстанс приложения (нет утечки состояния между тестами)', async () => {
    const app = buildTestApp();
    const res = await request(app).get('/ping');
    expect(res.status).toBe(200); // не 429, хотя предыдущий тест уже исчерпал лимит на СВОЁМ app
  });
});
