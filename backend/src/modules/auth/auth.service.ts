import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { AuthRepository } from './auth.repository';
import { SocialProvider, UserRow } from './auth.model';
import { GoogleTokenVerifier, RealGoogleTokenVerifier } from './google.verifier';
import { VkAuthVerifier, RealVkAuthVerifier } from './vk.verifier';
import { RealTelegramAuthVerifier, TelegramAuthVerifier, TelegramLoginPayload } from './telegram.verifier';

const TOKEN_TTL = '90d';
const PASSWORD_SALT_ROUNDS = 10;

export class EmailAlreadyRegisteredError extends Error {
  constructor() {
    super('Email already registered');
  }
}

export class InvalidCredentialsError extends Error {
  constructor() {
    super('Invalid email or password');
  }
}

/** Общие ошибки для всех соцсетей — не плодим по паре классов на
 * провайдера, только различаем через .provider. */
export class SocialAuthNotConfiguredError extends Error {
  constructor(public readonly provider: SocialProvider) {
    super(`${provider} sign-in is not configured on this server`);
  }
}

export class InvalidSocialTokenError extends Error {
  constructor(public readonly provider: SocialProvider) {
    super(`Invalid ${provider} token`);
  }
}

export interface AuthResult {
  token: string;
  user: { id: string; email: string; name: string };
}

export interface SocialAuthResult extends AuthResult {
  isNewUser: boolean;
}

export class AuthService {
  private readonly googleVerifier: GoogleTokenVerifier | null;
  private readonly vkVerifier: VkAuthVerifier | null;
  private readonly telegramVerifier: TelegramAuthVerifier | null;

  constructor(
    private readonly repository: AuthRepository,
    verifiers?: { google?: GoogleTokenVerifier; vk?: VkAuthVerifier; telegram?: TelegramAuthVerifier },
  ) {
    this.googleVerifier = verifiers?.google ?? (env.googleClientId ? new RealGoogleTokenVerifier(env.googleClientId) : null);
    this.vkVerifier =
      verifiers?.vk ?? (env.vkClientId && env.vkClientSecret ? new RealVkAuthVerifier(env.vkClientId, env.vkClientSecret) : null);
    this.telegramVerifier = verifiers?.telegram ?? (env.telegramBotToken ? new RealTelegramAuthVerifier(env.telegramBotToken) : null);
  }

  async register(email: string, password: string, name: string): Promise<AuthResult> {
    const existing = await this.repository.findByEmail(email);
    if (existing) throw new EmailAlreadyRegisteredError();

    const passwordHash = await bcrypt.hash(password, PASSWORD_SALT_ROUNDS);
    const user = await this.repository.create(email, passwordHash, name);
    return { token: this.issueToken(user.id), user: toPublicUser(user) };
  }

  async login(email: string, password: string): Promise<AuthResult> {
    const user = await this.repository.findByEmail(email);
    if (!user || !user.password_hash) throw new InvalidCredentialsError();

    const passwordMatches = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatches) throw new InvalidCredentialsError();

    return { token: this.issueToken(user.id), user: toPublicUser(user) };
  }

  async loginWithGoogle(idToken: string): Promise<SocialAuthResult> {
    if (!this.googleVerifier) throw new SocialAuthNotConfiguredError('google');
    const payload = await this.googleVerifier.verify(idToken);
    if (!payload) throw new InvalidSocialTokenError('google');
    return this.findOrCreateSocialUser('google', payload.googleId, payload.email, payload.name);
  }

  async loginWithVk(code: string, redirectUri: string): Promise<SocialAuthResult> {
    if (!this.vkVerifier) throw new SocialAuthNotConfiguredError('vk');
    const payload = await this.vkVerifier.exchangeCode(code, redirectUri);
    if (!payload) throw new InvalidSocialTokenError('vk');
    const email = payload.email ?? `vk${payload.vkId}@users.razvit.local`;
    return this.findOrCreateSocialUser('vk', payload.vkId, email, payload.name || 'Пользователь VK');
  }

  async loginWithTelegram(payload: TelegramLoginPayload): Promise<SocialAuthResult> {
    if (!this.telegramVerifier) throw new SocialAuthNotConfiguredError('telegram');
    const verified = this.telegramVerifier.verify(payload);
    if (!verified) throw new InvalidSocialTokenError('telegram');
    const email = `tg${verified.telegramId}@users.razvit.local`;
    return this.findOrCreateSocialUser('telegram', verified.telegramId, email, verified.name || 'Пользователь Telegram');
  }

  /** Общая логика для всех соцсетей: уже привязан — логиним; есть аккаунт
   * с таким email (например, регистрировался по паролю) — привязываем
   * соцсеть к нему, не плодим дубликат; иначе — создаём нового пользователя. */
  private async findOrCreateSocialUser(
    provider: SocialProvider,
    socialId: string,
    email: string,
    name: string,
  ): Promise<SocialAuthResult> {
    const bySocialId = await this.repository.findBySocialId(provider, socialId);
    if (bySocialId) {
      return { token: this.issueToken(bySocialId.id), user: toPublicUser(bySocialId), isNewUser: false };
    }

    const byEmail = await this.repository.findByEmail(email);
    if (byEmail) {
      const linked = await this.repository.linkSocialId(provider, byEmail.id, socialId);
      return { token: this.issueToken(linked.id), user: toPublicUser(linked), isNewUser: false };
    }

    const created = await this.repository.createFromSocial(provider, email, name, socialId);
    return { token: this.issueToken(created.id), user: toPublicUser(created), isNewUser: true };
  }

  async me(userId: string): Promise<AuthResult['user'] | null> {
    const user = await this.repository.findById(userId);
    return user ? toPublicUser(user) : null;
  }

  private issueToken(userId: string): string {
    return jwt.sign({ sub: userId }, env.jwtSecret, { expiresIn: TOKEN_TTL });
  }
}

function toPublicUser(user: UserRow): AuthResult['user'] {
  return { id: user.id, email: user.email, name: user.name };
}
