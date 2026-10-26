import { FoodRepository } from '../food/food.repository';
import { FoodNotFoundError } from '../food/food.service';
import { FoodAmount, MicronutrientMap, NutrientSource } from './nutrition.model';

/** Одна строка запроса на расчёт: либо `foodId` (продукт из базы), либо
 * готовые нутриенты (для ручного ввода — продукт, которого нет в базе). */
export interface FoodAmountInput {
  foodId?: string;
  nutrients?: NutrientSource;
  grams: number;
}

/**
 * Превращает вход API (foodId | nutrients) в FoodAmount с реальными
 * нутриентами — единым пакетным запросом к базе для всех foodId сразу
 * (без N+1). Если foodId не найден — кидает FoodNotFoundError (уже
 * используется в Food Database для тех же целей, тот же код ошибки/404).
 */
export class NutritionInputResolver {
  constructor(private readonly foods: FoodRepository) {}

  async resolve(items: FoodAmountInput[]): Promise<FoodAmount[]> {
    const idsToLoad = [...new Set(items.filter((i) => i.foodId).map((i) => i.foodId as string))];
    const [foodRows, micronutrientRows] = await Promise.all([
      this.foods.findByIds(idsToLoad),
      this.foods.getMicronutrientsForFoods(idsToLoad),
    ]);

    const foodById = new Map(foodRows.map((f) => [f.id, f]));
    const micronutrientsByFood = new Map<string, MicronutrientMap>();
    for (const m of micronutrientRows) {
      const map = micronutrientsByFood.get(m.food_id) ?? {};
      map[m.key] = { amount: Number(m.amount), unit: m.unit };
      micronutrientsByFood.set(m.food_id, map);
    }

    return items.map((item) => {
      if (item.nutrients) {
        return { food: item.nutrients, grams: item.grams };
      }
      const row = foodById.get(item.foodId as string);
      if (!row) throw new FoodNotFoundError();
      const source: NutrientSource = {
        calories: Number(row.calories),
        protein: Number(row.protein),
        fat: Number(row.fat),
        carbohydrates: Number(row.carbohydrates),
        fiber: Number(row.fiber),
        sugar: row.sugar != null ? Number(row.sugar) : null,
        sodium: row.sodium != null ? Number(row.sodium) : null,
        micronutrients: micronutrientsByFood.get(row.id) ?? {},
      };
      return { food: source, grams: item.grams };
    });
  }
}
