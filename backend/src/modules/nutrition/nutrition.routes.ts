import { Router } from 'express';
import { pool } from '../../db/pool';
import { validate } from '../../middleware/validate';
import { FoodRepository } from '../food/food.repository';
import { NutritionCalculationService } from './nutrition.calculation.service';
import { NutritionController } from './nutrition.controller';
import { NutritionInputResolver } from './nutrition.resolver';
import {
  calculateDaySchema,
  calculateFoodSchema,
  calculateMealSchema,
  calculateRecipeSchema,
  calculateWeekSchema,
} from './nutrition.validation';

const foodRepository = new FoodRepository(pool);
const engine = new NutritionCalculationService();
const resolver = new NutritionInputResolver(foodRepository);
const controller = new NutritionController(engine, resolver);

export const nutritionRouter = Router();

nutritionRouter.post('/nutrition/calculate/food', validate(calculateFoodSchema, 'body'), controller.calculateFood);
nutritionRouter.post('/nutrition/calculate/meal', validate(calculateMealSchema, 'body'), controller.calculateMeal);
nutritionRouter.post('/nutrition/calculate/recipe', validate(calculateRecipeSchema, 'body'), controller.calculateRecipe);
nutritionRouter.post('/nutrition/calculate/day', validate(calculateDaySchema, 'body'), controller.calculateDay);
nutritionRouter.post('/nutrition/calculate/week', validate(calculateWeekSchema, 'body'), controller.calculateWeek);

export { NutritionCalculationService, NutritionController, NutritionInputResolver };
