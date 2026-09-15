import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { aiRateLimiter } from '../../middleware/rateLimiter';
import { validate } from '../../middleware/validate';
import { RecipeGeneratorClient } from '../../integrations/recipeGeneratorClient';
import { FoodRepository } from '../food/food.repository';
import { FoodMatchingService } from '../food/food.matching';
import { NutritionCalculationService } from '../nutrition/nutrition.calculation.service';
import { RecipeGeneratorController } from './recipeGenerator.controller';
import { RecipeGeneratorService } from './recipeGenerator.service';
import { generateRecipeSchema } from './recipeGenerator.validation';

const foodRepository = new FoodRepository(pool);
const matching = new FoodMatchingService(foodRepository);
const engine = new NutritionCalculationService();
const client = new RecipeGeneratorClient();
const service = new RecipeGeneratorService(client, matching, engine);
const controller = new RecipeGeneratorController(service);

export const recipeGeneratorRouter = Router();

recipeGeneratorRouter.post('/recipe-generator/generate', authUser, aiRateLimiter, validate(generateRecipeSchema, 'body'), controller.generate);

// Экспортируем для тестов, которым нужны собранные вручную экземпляры с фейковым RecipeGeneratorClient.
export { RecipeGeneratorController, RecipeGeneratorService };
