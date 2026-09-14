import cors from 'cors';
import express, { Express } from 'express';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import { authRouter } from './modules/auth/auth.routes';
import { foodRouter } from './modules/food/food.routes';
import { foodRecognitionRouter } from './modules/foodRecognition/foodRecognition.routes';
import { mealRouter } from './modules/meal/meal.routes';
import { nutritionRouter } from './modules/nutrition/nutrition.routes';
import { recipeRouter } from './modules/recipe/recipe.routes';
import { recipeGeneratorRouter } from './modules/recipeGenerator/recipeGenerator.routes';

export function createApp(): Express {
  const app = express();
  app.use(cors());
  // 8mb — AI Food Recognition шлёт сжатое фото как base64 в JSON-теле
  // (см. foodRecognition.routes.ts); остальные эндпоинты этим лимитом
  // не пользуются, но общий парсер один на всё приложение.
  app.use(express.json({ limit: '8mb' }));

  app.get('/health', (_req, res) => res.status(200).json({ status: 'ok' }));

  app.use('/api/v1', authRouter);
  app.use('/api/v1', foodRouter);
  app.use('/api/v1', foodRecognitionRouter);
  app.use('/api/v1', mealRouter);
  app.use('/api/v1', nutritionRouter);
  app.use('/api/v1', recipeRouter);
  app.use('/api/v1', recipeGeneratorRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
