import { asyncHandler } from '../../utils/asyncHandler';
import { NutritionCalculationService } from './nutrition.calculation.service';
import { NutritionInputResolver } from './nutrition.resolver';
import {
  CalculateDayBody,
  CalculateFoodBody,
  CalculateMealBody,
  CalculateRecipeBody,
  CalculateWeekBody,
} from './nutrition.validation';

/**
 * Тонкий слой HTTP поверх NutritionCalculationService: разбирает вход,
 * резолвит foodId в реальные нутриенты через NutritionInputResolver,
 * зовёт чистый расчётный сервис и отдаёт результат. Сама математика
 * здесь не живёт — она только в NutritionCalculationService.
 */
export class NutritionController {
  constructor(
    private readonly engine: NutritionCalculationService,
    private readonly resolver: NutritionInputResolver,
  ) {}

  calculateFood = asyncHandler(async (req, res) => {
    const body = req.validatedBody as CalculateFoodBody;
    const [amount] = await this.resolver.resolve([body]);
    res.status(200).json({ data: this.engine.forFoodAmount(amount.food, amount.grams) });
  });

  calculateMeal = asyncHandler(async (req, res) => {
    const body = req.validatedBody as CalculateMealBody;
    const items = await this.resolver.resolve(body.items);
    res.status(200).json({ data: this.engine.forMeal(items) });
  });

  calculateRecipe = asyncHandler(async (req, res) => {
    const body = req.validatedBody as CalculateRecipeBody;
    const items = await this.resolver.resolve(body.items);
    res.status(200).json({ data: this.engine.forRecipe(items, body.servings) });
  });

  calculateDay = asyncHandler(async (req, res) => {
    const body = req.validatedBody as CalculateDayBody;
    const meals = await Promise.all(body.meals.map((meal) => this.resolver.resolve(meal.items)));
    res.status(200).json({ data: this.engine.forDay(meals) });
  });

  calculateWeek = asyncHandler(async (req, res) => {
    const body = req.validatedBody as CalculateWeekBody;
    res.status(200).json({ data: this.engine.forWeek(body.days) });
  });
}
