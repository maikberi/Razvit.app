import { NextFunction, Request, Response } from 'express';
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

  // eslint-disable-next-line no-console
  console.error(err);
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Внутренняя ошибка сервера' } });
}

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({ error: { code: 'ROUTE_NOT_FOUND', message: `Route ${req.method} ${req.path} not found` } });
}
