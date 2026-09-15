import { NextFunction, Request, Response } from 'express';
import {
  EmailAlreadyRegisteredError,
  InvalidCredentialsError,
  InvalidSocialTokenError,
  SocialAuthNotConfiguredError,
} from '../modules/auth/auth.service';
import { SocialProvider } from '../modules/auth/auth.model';
import { DuplicateFoodError, FoodNotFoundError } from '../modules/food/food.service';
import { serializeFood } from '../modules/food/food.serializer';
import { InvalidImageError } from '../modules/foodRecognition/foodRecognition.service';
import { ForbiddenError, MealItemNotFoundError, MealNotFoundError } from '../modules/meal/meal.service';
import { WaterEntryNotFoundError } from '../modules/nutrition/nutrition.daily.service';
import { IncompleteNutritionProfileError } from '../modules/nutrition/nutritionTarget.service';
import { RecipeIngredientFoodNotFoundError, RecipeIngredientUnitError, RecipeNotFoundError } from '../modules/recipe/recipe.service';
import { VisionNotConfiguredError, VisionRateLimitError, VisionTimeoutError, VisionUnavailableError } from '../integrations/visionClient';
import {
  RecipeAiNotConfiguredError,
  RecipeAiRateLimitError,
  RecipeAiTimeoutError,
  RecipeAiUnavailableError,
} from '../integrations/recipeGeneratorClient';
import { logEvent } from '../utils/logger';
import { TrainerAccessDeniedError } from '../modules/trainer/trainer.access.service';
import {
  AlreadyConnectedError,
  AssignmentNotFoundError,
  CannotInviteSelfError,
  ClientNotFoundError,
  InvalidRelationStateError,
  TrainerRelationNotFoundError,
} from '../modules/trainer/trainer.service';

const SOCIAL_PROVIDER_LABELS: Record<SocialProvider, string> = { google: 'Google', vk: 'VK', telegram: 'Telegram' };

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
  if (err instanceof RecipeNotFoundError) {
    res.status(404).json({ error: { code: 'RECIPE_NOT_FOUND', message: 'Рецепт не найден' } });
    return;
  }
  if (err instanceof RecipeIngredientFoodNotFoundError) {
    res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Некорректные данные',
        details: { ingredients: `Продукт ${err.foodId} не найден` },
      },
    });
    return;
  }
  if (err instanceof RecipeIngredientUnitError) {
    res.status(422).json({
      error: {
        code: 'RECIPE_INGREDIENT_UNIT_UNSUPPORTED',
        message: `У продукта «${err.foodName}» не задан размер порции — количество в штуках посчитать нельзя`,
        details: { foodId: err.foodId },
      },
    });
    return;
  }
  if (err instanceof WaterEntryNotFoundError) {
    res.status(404).json({ error: { code: 'WATER_ENTRY_NOT_FOUND', message: 'Запись о воде не найдена' } });
    return;
  }
  if (err instanceof IncompleteNutritionProfileError) {
    res.status(422).json({
      error: {
        code: 'NUTRITION_PROFILE_INCOMPLETE',
        message: 'Заполни все данные профиля, чтобы рассчитать цели',
        details: { missingFields: err.missingFields },
      },
    });
    return;
  }
  if (err instanceof InvalidImageError) {
    res.status(422).json({ error: { code: 'INVALID_IMAGE', message: err.message } });
    return;
  }
  if (err instanceof VisionNotConfiguredError) {
    // Не сбой, а конфигурация — но логируем всё равно: если это видно в
    // проде, значит ANTHROPIC_API_KEY не выставлен, а должен быть.
    logEvent('ai_failure', { integration: 'vision', reason: 'not_configured' });
    res.status(503).json({ error: { code: 'AI_NOT_CONFIGURED', message: 'Распознавание фото временно недоступно' } });
    return;
  }
  if (err instanceof VisionTimeoutError) {
    logEvent('ai_failure', { integration: 'vision', reason: 'timeout' });
    res.status(504).json({ error: { code: 'AI_TIMEOUT', message: 'Распознавание фото заняло слишком много времени, попробуй ещё раз' } });
    return;
  }
  if (err instanceof VisionRateLimitError) {
    logEvent('ai_failure', { integration: 'vision', reason: 'rate_limited' });
    res.status(429).json({ error: { code: 'AI_RATE_LIMITED', message: 'Слишком много запросов на распознавание, попробуй через минуту' } });
    return;
  }
  if (err instanceof VisionUnavailableError) {
    logEvent('ai_failure', { integration: 'vision', reason: 'unavailable', detail: err.message });
    res.status(503).json({ error: { code: 'AI_UNAVAILABLE', message: 'Сервис распознавания фото временно недоступен, попробуй позже' } });
    return;
  }
  if (err instanceof RecipeAiNotConfiguredError) {
    logEvent('ai_failure', { integration: 'recipe_generator', reason: 'not_configured' });
    res.status(503).json({ error: { code: 'AI_NOT_CONFIGURED', message: 'Генерация рецептов временно недоступна' } });
    return;
  }
  if (err instanceof RecipeAiTimeoutError) {
    logEvent('ai_failure', { integration: 'recipe_generator', reason: 'timeout' });
    res.status(504).json({ error: { code: 'AI_TIMEOUT', message: 'Генерация рецепта заняла слишком много времени, попробуй ещё раз' } });
    return;
  }
  if (err instanceof RecipeAiRateLimitError) {
    logEvent('ai_failure', { integration: 'recipe_generator', reason: 'rate_limited' });
    res.status(429).json({ error: { code: 'AI_RATE_LIMITED', message: 'Слишком много запросов на генерацию рецептов, попробуй через минуту' } });
    return;
  }
  if (err instanceof RecipeAiUnavailableError) {
    logEvent('ai_failure', { integration: 'recipe_generator', reason: 'unavailable', detail: err.message });
    res.status(503).json({ error: { code: 'AI_UNAVAILABLE', message: 'Сервис генерации рецептов временно недоступен, попробуй позже' } });
    return;
  }
  if (err instanceof TrainerAccessDeniedError) {
    res.status(403).json({ error: { code: 'TRAINER_ACCESS_DENIED', message: 'Нет подтверждённой связи с этим клиентом' } });
    return;
  }
  if (err instanceof ClientNotFoundError) {
    res.status(404).json({ error: { code: 'CLIENT_NOT_FOUND', message: 'Пользователь с таким email не найден' } });
    return;
  }
  if (err instanceof CannotInviteSelfError) {
    res.status(422).json({ error: { code: 'CANNOT_INVITE_SELF', message: 'Нельзя пригласить самого себя' } });
    return;
  }
  if (err instanceof AlreadyConnectedError) {
    res.status(409).json({ error: { code: 'ALREADY_CONNECTED', message: 'С этим клиентом уже есть подтверждённая связь' } });
    return;
  }
  if (err instanceof TrainerRelationNotFoundError) {
    res.status(404).json({ error: { code: 'TRAINER_RELATION_NOT_FOUND', message: 'Связь тренер-клиент не найдена' } });
    return;
  }
  if (err instanceof InvalidRelationStateError) {
    res.status(409).json({ error: { code: 'TRAINER_RELATION_INVALID_STATE', message: err.message } });
    return;
  }
  if (err instanceof AssignmentNotFoundError) {
    res.status(404).json({ error: { code: 'ASSIGNMENT_NOT_FOUND', message: 'Назначение не найдено' } });
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
  if (err instanceof InvalidSocialTokenError) {
    const code = `INVALID_${err.provider.toUpperCase()}_TOKEN`;
    res.status(401).json({ error: { code, message: `Не удалось подтвердить вход через ${SOCIAL_PROVIDER_LABELS[err.provider]}` } });
    return;
  }
  if (err instanceof SocialAuthNotConfiguredError) {
    const code = `${err.provider.toUpperCase()}_AUTH_NOT_CONFIGURED`;
    res.status(503).json({ error: { code, message: `Вход через ${SOCIAL_PROVIDER_LABELS[err.provider]} временно недоступен` } });
    return;
  }

  // eslint-disable-next-line no-console
  console.error(err);
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Внутренняя ошибка сервера' } });
}

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({ error: { code: 'ROUTE_NOT_FOUND', message: `Route ${req.method} ${req.path} not found` } });
}
