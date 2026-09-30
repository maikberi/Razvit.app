import { createHash, createHmac, timingSafeEqual } from 'crypto';

export interface TelegramLoginPayload {
  id: string | number;
  first_name: string;
  last_name?: string;
  username?: string;
  photo_url?: string;
  auth_date: string | number;
  hash: string;
}

export interface TelegramPayload {
  telegramId: string;
  name: string;
}

/** Абстракция вокруг проверки подписи Telegram Login — позволяет
 * подменить в тестах без реального бота. */
export interface TelegramAuthVerifier {
  verify(payload: TelegramLoginPayload): TelegramPayload | null;
}

const MAX_AUTH_AGE_SECONDS = 24 * 60 * 60; // сутки — с более старым payload не доверяем (см. доки Telegram Login)

export class RealTelegramAuthVerifier implements TelegramAuthVerifier {
  private readonly secretKey: Buffer;

  constructor(botToken: string) {
    this.secretKey = createHash('sha256').update(botToken).digest();
  }

  verify(payload: TelegramLoginPayload): TelegramPayload | null {
    const { hash, ...rest } = payload;
    if (!hash) return null;

    const dataCheckString = Object.keys(rest)
      .sort()
      .map((key) => `${key}=${(rest as Record<string, unknown>)[key]}`)
      .join('\n');

    const expectedHash = createHmac('sha256', this.secretKey).update(dataCheckString).digest('hex');

    const expected = Buffer.from(expectedHash, 'hex');
    const actual = Buffer.from(hash, 'hex');
    if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) return null;

    const authDate = Number(payload.auth_date);
    if (!Number.isFinite(authDate) || Date.now() / 1000 - authDate > MAX_AUTH_AGE_SECONDS) return null;

    return {
      telegramId: String(payload.id),
      name: [payload.first_name, payload.last_name].filter(Boolean).join(' ').trim(),
    };
  }
}
