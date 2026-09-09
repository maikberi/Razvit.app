import request from 'supertest';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { AuthRepository } from '../src/modules/auth/auth.repository';
import { AuthService, InvalidGoogleTokenError } from '../src/modules/auth/auth.service';
import { GooglePayload, GoogleTokenVerifier } from '../src/modules/auth/google.verifier';

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
  return `google-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
}

/** Поддельный verifier — реальные токены Google в тестах недоступны, но вся
 * бизнес-логика (создание/связывание/поиск пользователя) от способа
 * проверки токена не зависит, поэтому подменяем только эту границу. */
class FakeGoogleVerifier implements GoogleTokenVerifier {
  constructor(private readonly payload: GooglePayload | null) {}
  async verify(): Promise<GooglePayload | null> {
    return this.payload;
  }
}

describe('Google auth (unit, через AuthService напрямую)', () => {
  it('первый вход через Google создаёт нового пользователя', async () => {
    const email = uniqueEmail();
    const service = new AuthService(new AuthRepository(pool), new FakeGoogleVerifier({ googleId: 'g-1', email, name: 'Гугл Тест' }));

    const result = await service.loginWithGoogle('fake-token');

    expect(result.isNewUser).toBe(true);
    expect(result.user).toMatchObject({ email, name: 'Гугл Тест' });
    expect(result.token).toEqual(expect.any(String));
  });

  it('повторный вход тем же Google-аккаунтом возвращает того же пользователя, isNewUser=false', async () => {
    const email = uniqueEmail();
    const service = new AuthService(new AuthRepository(pool), new FakeGoogleVerifier({ googleId: 'g-2', email, name: 'Гугл Тест' }));

    const first = await service.loginWithGoogle('fake-token');
    const second = await service.loginWithGoogle('fake-token');

    expect(second.isNewUser).toBe(false);
    expect(second.user.id).toBe(first.user.id);
  });

  it('вход через Google с email существующего (парольного) аккаунта — привязывает Google к нему, не плодит дубликат', async () => {
    const email = uniqueEmail();
    const repository = new AuthRepository(pool);
    const passwordService = new AuthService(repository);
    const registered = await passwordService.register(email, 'supersecret1', 'Обычный Юзер');

    const googleService = new AuthService(repository, new FakeGoogleVerifier({ googleId: 'g-3', email, name: 'Обычный Юзер' }));
    const result = await googleService.loginWithGoogle('fake-token');

    expect(result.isNewUser).toBe(false);
    expect(result.user.id).toBe(registered.user.id);
  });

  it('невалидный/непроверяемый токен — InvalidGoogleTokenError', async () => {
    const service = new AuthService(new AuthRepository(pool), new FakeGoogleVerifier(null));
    await expect(service.loginWithGoogle('garbage')).rejects.toBeInstanceOf(InvalidGoogleTokenError);
  });
});

describe('POST /auth/google (HTTP-контракт)', () => {
  it('без idToken в теле — 422', async () => {
    const res = await request(app).post('/api/v1/auth/google').send({});
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('без настроенного GOOGLE_CLIENT_ID — 503 GOOGLE_AUTH_NOT_CONFIGURED', async () => {
    // В тестовом окружении GOOGLE_CLIENT_ID не задан — реальный роут должен
    // явно сообщать об этом, а не падать с 500 или тихо молчать.
    const res = await request(app).post('/api/v1/auth/google').send({ idToken: 'whatever' });
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('GOOGLE_AUTH_NOT_CONFIGURED');
  });
});
