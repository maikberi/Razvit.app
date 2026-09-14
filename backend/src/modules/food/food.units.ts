import { FoodRow } from './food.model';

export type FoodQuantityUnit = 'g' | 'ml' | 'pcs';

/** Продукт в 'pcs' (штуках) без заданного serving_size — перевести в граммы нечем. */
export class FoodQuantityUnitError extends Error {
  constructor(
    public readonly foodId: string,
    public readonly foodName: string,
  ) {
    super(`Food "${foodName}" has no serving size defined — cannot use unit "pcs"`);
    this.name = 'FoodQuantityUnitError';
  }
}

/**
 * Переводит количество продукта в граммы/мл — базис, который понимает
 * NutritionCalculationService. 'g'/'ml' — это уже тот же базис, что и у
 * продукта (basis_unit), берём как есть. 'pcs' — через serving_size
 * продукта ("1 штука = N г/мл", то же поле, что показывает Flutter как
 * "1 порция"); без него посчитать нельзя.
 *
 * Общее место для Recipe (recipe.service.ts) и AI Recipe Generator
 * (recipeGenerator.service.ts) — оба переводят ингредиент в граммы
 * одинаково, до вызова Nutrition Engine.
 */
export function convertToGrams(food: FoodRow, quantity: number, unit: FoodQuantityUnit): number {
  if (unit !== 'pcs') return quantity;
  if (food.serving_size == null) {
    throw new FoodQuantityUnitError(food.id, food.name);
  }
  return quantity * Number(food.serving_size);
}
