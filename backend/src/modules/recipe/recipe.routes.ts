import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { validate } from '../../middleware/validate';
import { FoodRepository } from '../food/food.repository';
import { NutritionCalculationService } from '../nutrition/nutrition.calculation.service';
import { RecipeController } from './recipe.controller';
import { RecipeRepository } from './recipe.repository';
import { RecipeService } from './recipe.service';
import { recipeIdParamSchema, recipeInputSchema, recipeSearchQuerySchema } from './recipe.validation';

const recipeRepository = new RecipeRepository(pool);
const foodRepository = new FoodRepository(pool);
const engine = new NutritionCalculationService();
const service = new RecipeService(recipeRepository, foodRepository, engine);
const controller = new RecipeController(service);

export const recipeRouter = Router();

recipeRouter.get('/recipes', authUser, validate(recipeSearchQuerySchema, 'query'), controller.list);
recipeRouter.get('/recipes/:id', authUser, validate(recipeIdParamSchema, 'params'), controller.getById);
recipeRouter.post('/recipes', authUser, validate(recipeInputSchema, 'body'), controller.create);
recipeRouter.put(
  '/recipes/:id',
  authUser,
  validate(recipeIdParamSchema, 'params'),
  validate(recipeInputSchema, 'body'),
  controller.update,
);
recipeRouter.delete('/recipes/:id', authUser, validate(recipeIdParamSchema, 'params'), controller.remove);
recipeRouter.post('/recipes/:id/favorite', authUser, validate(recipeIdParamSchema, 'params'), controller.favorite);
recipeRouter.delete('/recipes/:id/favorite', authUser, validate(recipeIdParamSchema, 'params'), controller.unfavorite);

// Экспортируем для тестов, которым нужны собранные вручную экземпляры на своём pool.
export { RecipeController, RecipeRepository, RecipeService };
