import { NextFunction, Request, Response } from 'express';
import {
  EmailAlreadyRegisteredError,
  GoogleAuthNotConfiguredError,
  InvalidCredentialsError,
  InvalidGoogleTokenError,
} from '../modules/auth/auth.service';
import { DuplicateFoodError, FoodNotFoundError } from '../modules/food/food.service';
import { serializeFood } from '../modules/food/food.serializer';
import { ForbiddenError, MealItemNotFoundError, MealNotFoundError } from '../modules/meal/meal.service';

/** Единая точка превращения ошибок в HTTP-ответ по контракту {error:{code,message,details}}. */
// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: unknown, req: Request, res: Response, next: NextFunction): void {
  if (err instanceof FoodNotFoundError) {
    res.status(404).json({ error: { code: 'FOOD_NOT_FOUND', message: 'Продукт не найден' } });
    return;
  }
  if (err instanceof DuplicateFoodError) {
    res.status(409).json({
      error: {
        code: 'FOOD_DUPLICATE',
        message: 'Продукт с таким штрихкодом уже существует',
        details: { existing: serializeFood(err.existing) },
      },
    });
    return;
  }
  if (err instanceof MealNotFoundError) {
    res.status(404).json({ error: { code: 'MEAL_NOT_FOUND', message: 'Приём пищи не найден' } });
    return;
  }
  if (err instanceof MealItemNotFoundError) {
    res.status(404).json({ error: { code: 'MEAL_ITEM_NOT_FOUND', message: 'Запись не найдена' } });
    return;
  }
  if (err instanceof ForbiddenError) {
    res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Нет доступа к этому ресурсу' } });
    return;
  }
  if (err instanceof EmailAlreadyRegisteredError) {
    res.status(409).json({ error: { code: 'EMAIL_ALREADY_REGISTERED', message: 'Этот email уже зарегистрирован' } });
    return;
  }
  if (err instanceof InvalidCredentialsError) {
    res.status(401).json({ error: { code: 'INVALID_CREDENTIALS', message: 'Неверный email или пароль' } });
    return;
  }
  if (err instanceof InvalidGoogleTokenError) {
    res.status(401).json({ error: { code: 'INVALID_GOOGLE_TOKEN', message: 'Не удалось подтвердить вход через Google' } });
    return;
  }
  if (err instanceof GoogleAuthNotConfiguredError) {
    res.status(503).json({ error: { code: 'GOOGLE_AUTH_NOT_CONFIGURED', message: 'Вход через Google временно недоступен' } });
    return;
  }

  // eslint-disable-next-line no-console
  console.error(err);
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Внутренняя ошибка сервера' } });
}

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({ error: { code: 'ROUTE_NOT_FOUND', message: `Route ${req.method} ${req.path} not found` } });
}
