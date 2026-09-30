import { randomUUID } from 'crypto';
import jwt from 'jsonwebtoken';
import { env } from '../src/config/env';

/** Подписывает JWT для тестового пользователя — таблица users не используется
 * (как и раньше с device-id, user_id-колонки не ссылаются на неё через FK). */
export function authHeaderForUser(userId: string): { Authorization: string } {
  const token = jwt.sign({ sub: userId }, env.jwtSecret, { expiresIn: '1h' });
  return { Authorization: `Bearer ${token}` };
}

export function newTestUser(): { userId: string; header: { Authorization: string } } {
  const userId = randomUUID();
  return { userId, header: authHeaderForUser(userId) };
}
