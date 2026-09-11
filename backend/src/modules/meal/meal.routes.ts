import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { validate } from '../../middleware/validate';
import { FoodRepository } from '../food/food.repository';
import { NutritionCalculationService } from '../nutrition/nutrition.calculation.service';
import { MealController } from './meal.controller';
import { MealRepository } from './meal.repository';
import { MealService } from './meal.service';
import { addMealItemSchema, dateQuerySchema, mealIdParamSchema, mealItemIdParamSchema, updateMealItemSchema } from './meal.validation';

const mealRepository = new MealRepository(pool);
const foodRepository = new FoodRepository(pool);
const engine = new NutritionCalculationService();
const service = new MealService(mealRepository, foodRepository, engine);
const controller = new MealController(service);

export const mealRouter = Router();

// authUser подключается к каждому роуту отдельно (а не через router.use),
// иначе он перехватывал бы вообще все запросы под /api/v1, включая
// маршруты других модулей (foodRouter/nutritionRouter), смонтированных
// на тот же префикс после mealRouter в app.ts.
mealRouter.get('/meals', authUser, validate(dateQuerySchema, 'query'), controller.getDay);
mealRouter.post(
  '/meals/:id/items',
  authUser,
  validate(mealIdParamSchema, 'params'),
  validate(addMealItemSchema, 'body'),
  controller.addItem,
);
mealRouter.patch(
  '/meal-items/:id',
  authUser,
  validate(mealItemIdParamSchema, 'params'),
  validate(updateMealItemSchema, 'body'),
  controller.updateItem,
);
mealRouter.delete('/meal-items/:id', authUser, validate(mealItemIdParamSchema, 'params'), controller.deleteItem);

export { MealRepository, MealService };
