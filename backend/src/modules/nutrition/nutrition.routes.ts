import { Router } from 'express';
import { pool } from '../../db/pool';
import { deviceUser } from '../../middleware/deviceUser';
import { validate } from '../../middleware/validate';
import { FoodRepository } from '../food/food.repository';
import { MealRepository } from '../meal/meal.repository';
import { MealService } from '../meal/meal.service';
import { NutritionCalculationService } from './nutrition.calculation.service';
import { NutritionController } from './nutrition.controller';
import { NutritionDailyController } from './nutrition.daily.controller';
import { NutritionDailyService } from './nutrition.daily.service';
import { NutritionInputResolver } from './nutrition.resolver';
import { NutritionTargetsRepository } from './nutrition.targets.repository';
import { NutritionWaterRepository } from './nutrition.water.repository';
import {
  addWaterSchema,
  calculateDaySchema,
  calculateFoodSchema,
  calculateMealSchema,
  calculateRecipeSchema,
  calculateWeekSchema,
  dateQuerySchema,
  updateTargetsSchema,
} from './nutrition.validation';

const foodRepository = new FoodRepository(pool);
const engine = new NutritionCalculationService();
const resolver = new NutritionInputResolver(foodRepository);
const controller = new NutritionController(engine, resolver);

const mealService = new MealService(new MealRepository(pool), foodRepository, engine);
const targetsRepository = new NutritionTargetsRepository(pool);
const waterRepository = new NutritionWaterRepository(pool);
const dailyService = new NutritionDailyService(mealService, targetsRepository, waterRepository, engine);
const dailyController = new NutritionDailyController(dailyService, targetsRepository, waterRepository);

export const nutritionRouter = Router();

// Чистый расчётный движок — без привязки к пользователю.
nutritionRouter.post('/nutrition/calculate/food', validate(calculateFoodSchema, 'body'), controller.calculateFood);
nutritionRouter.post('/nutrition/calculate/meal', validate(calculateMealSchema, 'body'), controller.calculateMeal);
nutritionRouter.post('/nutrition/calculate/recipe', validate(calculateRecipeSchema, 'body'), controller.calculateRecipe);
nutritionRouter.post('/nutrition/calculate/day', validate(calculateDaySchema, 'body'), controller.calculateDay);
nutritionRouter.post('/nutrition/calculate/week', validate(calculateWeekSchema, 'body'), controller.calculateWeek);

// Данные конкретного пользователя (устройства) — цели, вода, дневная сводка.
nutritionRouter.get('/nutrition/daily', deviceUser, validate(dateQuerySchema, 'query'), dailyController.getDaily);
nutritionRouter.get('/nutrition/targets', deviceUser, dailyController.getTargets);
nutritionRouter.put('/nutrition/targets', deviceUser, validate(updateTargetsSchema, 'body'), dailyController.updateTargets);
nutritionRouter.get('/nutrition/water', deviceUser, validate(dateQuerySchema, 'query'), dailyController.getWater);
nutritionRouter.post('/nutrition/water', deviceUser, validate(addWaterSchema, 'body'), dailyController.addWater);
nutritionRouter.delete(
  '/nutrition/water/last',
  deviceUser,
  validate(dateQuerySchema, 'query'),
  dailyController.removeLastWater,
);

export { NutritionCalculationService, NutritionController, NutritionInputResolver };
