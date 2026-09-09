import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { AuthRepository } from './auth.repository';
import { UserRow } from './auth.model';
import { GoogleTokenVerifier, RealGoogleTokenVerifier } from './google.verifier';

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

export class InvalidGoogleTokenError extends Error {
  constructor() {
    super('Invalid Google token');
  }
}

export class GoogleAuthNotConfiguredError extends Error {
  constructor() {
    super('Google sign-in is not configured on this server');
  }
}

export interface AuthResult {
  token: string;
  user: { id: string; email: string; name: string };
}

export interface GoogleAuthResult extends AuthResult {
  isNewUser: boolean;
}

export class AuthService {
  private readonly googleVerifier: GoogleTokenVerifier | null;

  constructor(
    private readonly repository: AuthRepository,
    googleVerifier?: GoogleTokenVerifier,
  ) {
    this.googleVerifier = googleVerifier ?? (env.googleClientId ? new RealGoogleTokenVerifier(env.googleClientId) : null);
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

  async loginWithGoogle(idToken: string): Promise<GoogleAuthResult> {
    if (!this.googleVerifier) throw new GoogleAuthNotConfiguredError();

    const payload = await this.googleVerifier.verify(idToken);
    if (!payload) throw new InvalidGoogleTokenError();

    const byGoogleId = await this.repository.findByGoogleId(payload.googleId);
    if (byGoogleId) {
      return { token: this.issueToken(byGoogleId.id), user: toPublicUser(byGoogleId), isNewUser: false };
    }

    // Уже есть аккаунт с таким email (регистрировался по паролю) — просто
    // привязываем Google к нему, а не создаём дубликат пользователя.
    const byEmail = await this.repository.findByEmail(payload.email);
    if (byEmail) {
      const linked = await this.repository.linkGoogleId(byEmail.id, payload.googleId);
      return { token: this.issueToken(linked.id), user: toPublicUser(linked), isNewUser: false };
    }

    const created = await this.repository.createFromGoogle(payload.email, payload.name, payload.googleId);
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
