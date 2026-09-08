import { NextFunction, Request, Response } from 'express';

/**
 * Временная замена полноценной авторизации: Flutter присылает случайный
 * UUID устройства/установки в заголовке X-Device-Id (создаётся один раз
 * и хранится локально — см. lib/core/identity/device_identity.dart) —
 * используется как user_id для приёмов пищи/целей/воды/избранного.
 *
 * Это НЕ настоящая авторизация (данные не защищены паролем и привязаны
 * только к конкретному браузеру/устройству) — временный мост, чтобы
 * у каждого пользователя были свои данные уже сейчас. Когда появится
 * реальный вход, этот заголовок заменится на id из JWT/сессии — весь
 * остальной код (repositories/services), который просто получает
 * `req.userId` строкой, менять не придётся.
 */
export function deviceUser(req: Request, res: Response, next: NextFunction): void {
  const deviceId = req.header('X-Device-Id');
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  if (!deviceId || !uuidPattern.test(deviceId)) {
    res.status(400).json({
      error: { code: 'DEVICE_ID_REQUIRED', message: 'Заголовок X-Device-Id обязателен и должен быть UUID' },
    });
    return;
  }

  req.userId = deviceId;
  next();
}
