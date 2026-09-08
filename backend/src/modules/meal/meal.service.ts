import { FoodRepository } from '../food/food.repository';
import { FoodRow } from '../food/food.model';
import { NutritionCalculationService } from '../nutrition/nutrition.calculation.service';
import { FoodAmount, MicronutrientMap, NutrientSource } from '../nutrition/nutrition.model';
import { AddItemInput, MealRepository } from './meal.repository';
import { MealItemRow, MealRow } from './meal.model';

export class MealNotFoundError extends Error {
  constructor() {
    super('Meal not found');
    this.name = 'MealNotFoundError';
  }
}

export class MealItemNotFoundError extends Error {
  constructor() {
    super('Meal item not found');
    this.name = 'MealItemNotFoundError';
  }
}

export class ForbiddenError extends Error {
  constructor() {
    super('This resource belongs to a different user');
    this.name = 'ForbiddenError';
  }
}

export interface ComputedMealItem {
  id: string;
  foodId: string | null;
  name: string;
  grams: number;
  calories: number;
  protein: number;
  fat: number;
  carbohydrates: number;
  fiber: number;
  sugar: number | null;
  sodium: number | null;
}

export interface ComputedMeal {
  id: string;
  type: MealRow['type'];
  time: string | null;
  items: ComputedMealItem[];
  calories: number;
  protein: number;
  fat: number;
  carbohydrates: number;
  fiber: number;
  sugar: number | null;
  sodium: number | null;
  micronutrients: MicronutrientMap;
}

type FoodMaps = {
  foodById: Map<string, FoodRow>;
  micronutrientsByFood: Map<string, Record<string, { amount: number; unit: string }>>;
};

/**
 * Приёмы пищи — CRUD над записями + расчёт нутриентов через
 * NutritionCalculationService (сама математика — только там, здесь
 * только оркестрация: достать продукты, посчитать, собрать ответ).
 */
export class MealService {
  constructor(
    private readonly meals: MealRepository,
    private readonly foods: FoodRepository,
    private readonly engine: NutritionCalculationService,
  ) {}

  async getDay(userId: string, date: string): Promise<ComputedMeal[]> {
    const mealRows = await this.meals.ensureDayMeals(userId, date);
    const itemRows = await this.meals.getItemsForMeals(mealRows.map((m) => m.id));
    const maps = await this.loadFoodMaps(itemRows);

    const itemsByMeal = new Map<string, MealItemRow[]>();
    for (const item of itemRows) {
      const list = itemsByMeal.get(item.meal_id) ?? [];
      list.push(item);
      itemsByMeal.set(item.meal_id, list);
    }

    return mealRows.map((meal) => {
      const rows = itemsByMeal.get(meal.id) ?? [];
      const resolved = rows.map((row) => this.resolveRow(row, maps));
      const items = resolved.map(({ row, source, grams, name }) => this.toComputedItem(row, source, grams, name));
      const totals = this.engine.forMeal(resolved.map(({ source, grams }): FoodAmount => ({ food: source, grams })));
      return {
        id: meal.id,
        type: meal.type,
        time: meal.time,
        items,
        calories: totals.calories,
        protein: totals.protein,
        fat: totals.fat,
        carbohydrates: totals.carbohydrates,
        fiber: totals.fiber,
        sugar: totals.sugar,
        sodium: totals.sodium,
        micronutrients: totals.micronutrients,
      };
    });
  }

  private async loadFoodMaps(itemRows: MealItemRow[]): Promise<FoodMaps> {
    const foodIds = [...new Set(itemRows.filter((i) => i.food_id).map((i) => i.food_id as string))];
    const [foodRows, micronutrientRows] = await Promise.all([
      this.foods.findByIds(foodIds),
      this.foods.getMicronutrientsForFoods(foodIds),
    ]);
    const foodById = new Map(foodRows.map((f) => [f.id, f]));
    const micronutrientsByFood = new Map<string, Record<string, { amount: number; unit: string }>>();
    for (const m of micronutrientRows) {
      const map = micronutrientsByFood.get(m.food_id) ?? {};
      map[m.key] = { amount: Number(m.amount), unit: m.unit };
      micronutrientsByFood.set(m.food_id, map);
    }
    return { foodById, micronutrientsByFood };
  }

  /** Строку meal_items -> {нутриенты на 100 г, граммы, имя} — единственное место, где это собирается. */
  private resolveRow(row: MealItemRow, maps: FoodMaps): { row: MealItemRow; source: NutrientSource; grams: number; name: string } {
    const grams = Number(row.grams);
    if (row.food_id) {
      const food = maps.foodById.get(row.food_id);
      if (!food) throw new MealItemNotFoundError();
      const source: NutrientSource = {
        calories: Number(food.calories),
        protein: Number(food.protein),
        fat: Number(food.fat),
        carbohydrates: Number(food.carbohydrates),
        fiber: Number(food.fiber),
        sugar: food.sugar != null ? Number(food.sugar) : null,
        sodium: food.sodium != null ? Number(food.sodium) : null,
        micronutrients: maps.micronutrientsByFood.get(food.id) ?? {},
      };
      return { row, source, grams, name: food.name };
    }
    const n = row.custom_nutrients!;
    const source: NutrientSource = {
      calories: n.calories,
      protein: n.protein,
      fat: n.fat,
      carbohydrates: n.carbohydrates,
      fiber: n.fiber ?? 0,
      sugar: n.sugar ?? null,
      sodium: n.sodium ?? null,
    };
    return { row, source, grams, name: row.custom_name ?? 'Продукт' };
  }

  private toComputedItem(row: MealItemRow, source: NutrientSource, grams: number, name: string): ComputedMealItem {
    const computed = this.engine.forFoodAmount(source, grams);
    return {
      id: row.id,
      foodId: row.food_id,
      name,
      grams,
      calories: computed.calories,
      protein: computed.protein,
      fat: computed.fat,
      carbohydrates: computed.carbohydrates,
      fiber: computed.fiber,
      sugar: computed.sugar,
      sodium: computed.sodium,
    };
  }

  async addItem(userId: string, mealId: string, input: AddItemInput): Promise<ComputedMealItem> {
    const meal = await this.meals.findMealById(mealId);
    if (!meal) throw new MealNotFoundError();
    if (meal.user_id !== userId) throw new ForbiddenError();

    const row = await this.meals.addItem(mealId, input);
    if (input.foodId) {
      await this.foods.touchRecent(userId, input.foodId);
    }
    const maps = await this.loadFoodMaps([row]);
    const { source, grams, name } = this.resolveRow(row, maps);
    return this.toComputedItem(row, source, grams, name);
  }

  async updateItemGrams(userId: string, itemId: string, grams: number): Promise<void> {
    const found = await this.meals.findItemWithMeal(itemId);
    if (!found) throw new MealItemNotFoundError();
    if (found.meal.user_id !== userId) throw new ForbiddenError();
    await this.meals.updateItemGrams(itemId, grams);
  }

  async deleteItem(userId: string, itemId: string): Promise<void> {
    const found = await this.meals.findItemWithMeal(itemId);
    if (!found) throw new MealItemNotFoundError();
    if (found.meal.user_id !== userId) throw new ForbiddenError();
    await this.meals.deleteItem(itemId);
  }
}
