import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';

/**
 * Настоящая авторизация: Flutter присылает `Authorization: Bearer <jwt>`,
 * полученный при регистрации/входе (см. modules/auth). Здесь токен
 * проверяется и `req.userId` выставляется в id пользователя из таблицы
 * users — остальной код (repositories/services под /meals, /nutrition,
 * /foods/recent) не отличает его от прежнего device-id, он просто читает
 * `req.userId` строкой.
 */
export function authUser(req: Request, res: Response, next: NextFunction): void {
  const header = req.header('Authorization');
  const token = header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : undefined;

  if (!token) {
    res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Требуется авторизация' } });
    return;
  }

  try {
    const payload = jwt.verify(token, env.jwtSecret) as jwt.JwtPayload;
    if (typeof payload.sub !== 'string') throw new Error('missing sub claim');
    req.userId = payload.sub;
    next();
  } catch {
    res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Токен недействителен или истёк' } });
  }
}
