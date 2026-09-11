import cors from 'cors';
import express, { Express } from 'express';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import { authRouter } from './modules/auth/auth.routes';
import { foodRouter } from './modules/food/food.routes';
import { mealRouter } from './modules/meal/meal.routes';
import { nutritionRouter } from './modules/nutrition/nutrition.routes';
import { recipeRouter } from './modules/recipe/recipe.routes';

export function createApp(): Express {
  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get('/health', (_req, res) => res.status(200).json({ status: 'ok' }));

  app.use('/api/v1', authRouter);
  app.use('/api/v1', foodRouter);
  app.use('/api/v1', mealRouter);
  app.use('/api/v1', nutritionRouter);
  app.use('/api/v1', recipeRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
