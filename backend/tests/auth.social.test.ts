import request from 'supertest';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { AuthRepository } from '../src/modules/auth/auth.repository';
import { AuthService, InvalidSocialTokenError } from '../src/modules/auth/auth.service';
import { GooglePayload, GoogleTokenVerifier } from '../src/modules/auth/google.verifier';
import { VkAuthVerifier, VkExchangeParams, VkPayload } from '../src/modules/auth/vk.verifier';
import { TelegramAuthVerifier, TelegramLoginPayload, TelegramPayload } from '../src/modules/auth/telegram.verifier';

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

function uniqueEmail(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2)}@example.com`;
}

/** Поддельные verifier'ы — реальные токены/коды провайдеров в тестах
 * недоступны, но вся бизнес-логика (создание/связывание/поиск
 * пользователя) от способа проверки не зависит, поэтому подменяем
 * только эту границу. */
class FakeGoogleVerifier implements GoogleTokenVerifier {
  constructor(private readonly payload: GooglePayload | null) {}
  async verify(): Promise<GooglePayload | null> {
    return this.payload;
  }
}

class FakeVkVerifier implements VkAuthVerifier {
  constructor(private readonly payload: VkPayload | null) {}
  async exchangeCode(): Promise<VkPayload | null> {
    return this.payload;
  }
}

function vkExchangeParams(overrides: Partial<VkExchangeParams> = {}): VkExchangeParams {
  return {
    code: 'code',
    deviceId: 'device-1',
    codeVerifier: 'verifier-1',
    redirectUri: 'https://example.com/callback',
    state: 'state-1',
    ...overrides,
  };
}

class FakeTelegramVerifier implements TelegramAuthVerifier {
  constructor(private readonly payload: TelegramPayload | null) {}
  verify(): TelegramPayload | null {
    return this.payload;
  }
}

function telegramPayload(overrides: Partial<TelegramLoginPayload> = {}): TelegramLoginPayload {
  return {
    id: 123456,
    first_name: 'Телеграм',
    last_name: 'Тест',
    auth_date: Math.floor(Date.now() / 1000),
    hash: 'irrelevant-with-fake-verifier',
    ...overrides,
  };
}

describe('Google auth (unit, через AuthService напрямую)', () => {
  it('первый вход через Google создаёт нового пользователя', async () => {
    const email = uniqueEmail('google');
    const service = new AuthService(new AuthRepository(pool), { google: new FakeGoogleVerifier({ googleId: 'g-1', email, name: 'Гугл Тест' }) });

    const result = await service.loginWithGoogle('fake-token');

    expect(result.isNewUser).toBe(true);
    expect(result.user).toMatchObject({ email, name: 'Гугл Тест' });
    expect(result.token).toEqual(expect.any(String));
  });

  it('повторный вход тем же Google-аккаунтом возвращает того же пользователя, isNewUser=false', async () => {
    const email = uniqueEmail('google');
    const service = new AuthService(new AuthRepository(pool), { google: new FakeGoogleVerifier({ googleId: 'g-2', email, name: 'Гугл Тест' }) });

    const first = await service.loginWithGoogle('fake-token');
    const second = await service.loginWithGoogle('fake-token');

    expect(second.isNewUser).toBe(false);
    expect(second.user.id).toBe(first.user.id);
  });

  it('вход через Google с email существующего (парольного) аккаунта — привязывает Google к нему, не плодит дубликат', async () => {
    const email = uniqueEmail('google');
    const repository = new AuthRepository(pool);
    const passwordService = new AuthService(repository);
    const registered = await passwordService.register(email, 'supersecret1', 'Обычный Юзер');

    const googleService = new AuthService(repository, { google: new FakeGoogleVerifier({ googleId: 'g-3', email, name: 'Обычный Юзер' }) });
    const result = await googleService.loginWithGoogle('fake-token');

    expect(result.isNewUser).toBe(false);
    expect(result.user.id).toBe(registered.user.id);
  });

  it('невалидный/непроверяемый токен — InvalidSocialTokenError(google)', async () => {
    const service = new AuthService(new AuthRepository(pool), { google: new FakeGoogleVerifier(null) });
    await expect(service.loginWithGoogle('garbage')).rejects.toThrow(InvalidSocialTokenError);
  });
});

describe('VK auth (unit, через AuthService напрямую)', () => {
  it('первый вход через VK создаёт нового пользователя (email от VK)', async () => {
    const email = uniqueEmail('vk');
    const service = new AuthService(new AuthRepository(pool), { vk: new FakeVkVerifier({ vkId: '1', email, name: 'ВК Тест' }) });

    const result = await service.loginWithVk(vkExchangeParams());

    expect(result.isNewUser).toBe(true);
    expect(result.user).toMatchObject({ email, name: 'ВК Тест' });
  });

  it('VK без email — использует синтетический email, не роняет вход', async () => {
    const service = new AuthService(new AuthRepository(pool), { vk: new FakeVkVerifier({ vkId: '2', email: null, name: 'Без Почты' }) });

    const result = await service.loginWithVk(vkExchangeParams());

    expect(result.isNewUser).toBe(true);
    expect(result.user.email).toBe('vk2@users.razvit.local');
  });

  it('повторный вход тем же VK-аккаунтом — isNewUser=false, тот же пользователь', async () => {
    const email = uniqueEmail('vk');
    const service = new AuthService(new AuthRepository(pool), { vk: new FakeVkVerifier({ vkId: '3', email, name: 'ВК Тест' }) });

    const first = await service.loginWithVk(vkExchangeParams());
    const second = await service.loginWithVk(vkExchangeParams());

    expect(second.isNewUser).toBe(false);
    expect(second.user.id).toBe(first.user.id);
  });

  it('невалидный код — InvalidSocialTokenError(vk)', async () => {
    const service = new AuthService(new AuthRepository(pool), { vk: new FakeVkVerifier(null) });
    await expect(service.loginWithVk(vkExchangeParams({ code: 'bad-code' }))).rejects.toThrow(InvalidSocialTokenError);
  });
});

describe('Telegram auth (unit, через AuthService напрямую)', () => {
  it('первый вход через Telegram создаёт нового пользователя с синтетическим email', async () => {
    const service = new AuthService(new AuthRepository(pool), {
      telegram: new FakeTelegramVerifier({ telegramId: '111', name: 'Телеграм Тест' }),
    });

    const result = await service.loginWithTelegram(telegramPayload({ id: 111 }));

    expect(result.isNewUser).toBe(true);
    expect(result.user).toMatchObject({ email: 'tg111@users.razvit.local', name: 'Телеграм Тест' });
  });

  it('повторный вход тем же Telegram-аккаунтом — isNewUser=false', async () => {
    const service = new AuthService(new AuthRepository(pool), {
      telegram: new FakeTelegramVerifier({ telegramId: '222', name: 'Телеграм Тест' }),
    });

    const first = await service.loginWithTelegram(telegramPayload({ id: 222 }));
    const second = await service.loginWithTelegram(telegramPayload({ id: 222 }));

    expect(second.isNewUser).toBe(false);
    expect(second.user.id).toBe(first.user.id);
  });

  it('неверная подпись — InvalidSocialTokenError(telegram)', async () => {
    const service = new AuthService(new AuthRepository(pool), { telegram: new FakeTelegramVerifier(null) });
    await expect(service.loginWithTelegram(telegramPayload())).rejects.toThrow(InvalidSocialTokenError);
  });
});

describe('Реальная проверка подписи Telegram (RealTelegramAuthVerifier)', () => {
  it('верная подпись проходит проверку, неверная — нет', async () => {
    const { RealTelegramAuthVerifier } = await import('../src/modules/auth/telegram.verifier');
    const { createHash, createHmac } = await import('crypto');

    const botToken = 'test-bot-token';
    const payload = telegramPayload({ id: 999, hash: '' });
    const { hash: _omit, ...rest } = payload;
    const dataCheckString = Object.keys(rest)
      .sort()
      .map((key) => `${key}=${(rest as Record<string, unknown>)[key]}`)
      .join('\n');
    const secretKey = createHash('sha256').update(botToken).digest();
    const validHash = createHmac('sha256', secretKey).update(dataCheckString).digest('hex');

    const verifier = new RealTelegramAuthVerifier(botToken);
    expect(verifier.verify({ ...payload, hash: validHash })).toMatchObject({ telegramId: '999' });
    expect(verifier.verify({ ...payload, hash: 'a'.repeat(64) })).toBeNull();
  });

  it('слишком старый auth_date не проходит проверку', async () => {
    const { RealTelegramAuthVerifier } = await import('../src/modules/auth/telegram.verifier');
    const { createHash, createHmac } = await import('crypto');

    const botToken = 'test-bot-token';
    const oldAuthDate = Math.floor(Date.now() / 1000) - 2 * 24 * 60 * 60; // 2 дня назад
    const payload = telegramPayload({ id: 1000, auth_date: oldAuthDate, hash: '' });
    const { hash: _omit, ...rest } = payload;
    const dataCheckString = Object.keys(rest)
      .sort()
      .map((key) => `${key}=${(rest as Record<string, unknown>)[key]}`)
      .join('\n');
    const secretKey = createHash('sha256').update(botToken).digest();
    const validHash = createHmac('sha256', secretKey).update(dataCheckString).digest('hex');

    const verifier = new RealTelegramAuthVerifier(botToken);
    expect(verifier.verify({ ...payload, hash: validHash })).toBeNull();
  });
});

describe('POST /auth/google, /auth/vk, /auth/telegram (HTTP-контракт)', () => {
  it('POST /auth/google без idToken — 422', async () => {
    const res = await request(app).post('/api/v1/auth/google').send({});
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('POST /auth/google без настроенного GOOGLE_CLIENT_ID — 503', async () => {
    const res = await request(app).post('/api/v1/auth/google').send({ idToken: 'whatever' });
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('GOOGLE_AUTH_NOT_CONFIGURED');
  });

  it('POST /auth/vk без обязательных полей — 422', async () => {
    const res = await request(app).post('/api/v1/auth/vk').send({});
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('POST /auth/vk без настроенного VK_CLIENT_ID — 503', async () => {
    const res = await request(app).post('/api/v1/auth/vk').send(vkExchangeParams());
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('VK_AUTH_NOT_CONFIGURED');
  });

  it('POST /auth/telegram без обязательных полей — 422', async () => {
    const res = await request(app).post('/api/v1/auth/telegram').send({});
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('POST /auth/telegram без настроенного TELEGRAM_BOT_TOKEN — 503', async () => {
    const res = await request(app).post('/api/v1/auth/telegram').send(telegramPayload());
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('TELEGRAM_AUTH_NOT_CONFIGURED');
  });
});
