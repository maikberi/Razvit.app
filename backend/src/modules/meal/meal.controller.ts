import { asyncHandler } from '../../utils/asyncHandler';
import { MealService } from './meal.service';
import { AddMealItemBody, DateQuery, UpdateMealItemBody } from './meal.validation';

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

export class MealController {
  constructor(private readonly mealService: MealService) {}

  /** GET /meals?date=YYYY-MM-DD — все 4 приёма пищи за дату (по умолчанию сегодня), с посчитанными нутриентами. */
  getDay = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as DateQuery;
    const date = q.date ?? today();
    const meals = await this.mealService.getDay(req.userId as string, date);
    res.status(200).json({ data: { date, meals } });
  });

  /** POST /meals/:id/items */
  addItem = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    const body = req.validatedBody as AddMealItemBody;
    const item = await this.mealService.addItem(req.userId as string, id, {
      foodId: body.foodId ?? null,
      customName: body.name ?? null,
      customNutrients: body.nutrients
        ? {
            calories: body.nutrients.calories,
            protein: body.nutrients.protein,
            fat: body.nutrients.fat,
            carbohydrates: body.nutrients.carbohydrates,
            fiber: body.nutrients.fiber,
            sugar: body.nutrients.sugar,
            sodium: body.nutrients.sodium,
          }
        : null,
      grams: body.grams,
    });
    res.status(201).json({ data: item });
  });

  /** PATCH /meal-items/:id */
  updateItem = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    const body = req.validatedBody as UpdateMealItemBody;
    await this.mealService.updateItemGrams(req.userId as string, id, body.grams);
    res.status(204).send();
  });

  /** DELETE /meal-items/:id */
  deleteItem = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    await this.mealService.deleteItem(req.userId as string, id);
    res.status(204).send();
  });
}
