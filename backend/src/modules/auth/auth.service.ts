import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { AuthRepository } from './auth.repository';
import { UserRow } from './auth.model';

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

export interface AuthResult {
  token: string;
  user: { id: string; email: string; name: string };
}

export class AuthService {
  constructor(private readonly repository: AuthRepository) {}

  async register(email: string, password: string, name: string): Promise<AuthResult> {
    const existing = await this.repository.findByEmail(email);
    if (existing) throw new EmailAlreadyRegisteredError();

    const passwordHash = await bcrypt.hash(password, PASSWORD_SALT_ROUNDS);
    const user = await this.repository.create(email, passwordHash, name);
    return { token: this.issueToken(user.id), user: toPublicUser(user) };
  }

  async login(email: string, password: string): Promise<AuthResult> {
    const user = await this.repository.findByEmail(email);
    if (!user) throw new InvalidCredentialsError();

    const passwordMatches = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatches) throw new InvalidCredentialsError();

    return { token: this.issueToken(user.id), user: toPublicUser(user) };
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
