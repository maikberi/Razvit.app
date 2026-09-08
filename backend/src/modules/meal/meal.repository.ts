import { Pool } from 'pg';
import { MEAL_TYPES, MealItemRow, MealRow, MealType } from './meal.model';

export interface AddItemInput {
  foodId?: string | null;
  customName?: string | null;
  customNutrients?: MealItemRow['custom_nutrients'];
  grams: number;
}

export class MealRepository {
  constructor(private readonly pool: Pool) {}

  /** Гарантирует, что на дату существуют все 4 приёма пищи (создаёт недостающие). */
  async ensureDayMeals(userId: string, date: string): Promise<MealRow[]> {
    for (const type of MEAL_TYPES) {
      await this.pool.query(
        `INSERT INTO meals (user_id, type, date) VALUES ($1, $2, $3)
         ON CONFLICT (user_id, type, date) DO NOTHING`,
        [userId, type, date],
      );
    }
    const { rows } = await this.pool.query<MealRow>('SELECT * FROM meals WHERE user_id = $1 AND date = $2', [
      userId,
      date,
    ]);
    const order = new Map(MEAL_TYPES.map((t, i) => [t, i]));
    return rows.sort((a, b) => (order.get(a.type) ?? 0) - (order.get(b.type) ?? 0));
  }

  async getItemsForMeals(mealIds: string[]): Promise<MealItemRow[]> {
    if (mealIds.length === 0) return [];
    const { rows } = await this.pool.query<MealItemRow>(
      'SELECT * FROM meal_items WHERE meal_id = ANY($1::uuid[]) ORDER BY created_at',
      [mealIds],
    );
    return rows;
  }

  async findMealById(id: string): Promise<MealRow | null> {
    const { rows } = await this.pool.query<MealRow>('SELECT * FROM meals WHERE id = $1', [id]);
    return rows[0] ?? null;
  }

  /** Строка приёма пищи, которой принадлежит данный item — для проверки владения (userId) без второго запроса. */
  async findItemWithMeal(itemId: string): Promise<{ item: MealItemRow; meal: MealRow } | null> {
    const { rows } = await this.pool.query<MealItemRow & { meal_user_id: string; meal_type: MealType; meal_date: string }>(
      `SELECT mi.*, m.user_id AS meal_user_id, m.type AS meal_type, m.date AS meal_date
       FROM meal_items mi JOIN meals m ON m.id = mi.meal_id
       WHERE mi.id = $1`,
      [itemId],
    );
    const row = rows[0];
    if (!row) return null;
    const { meal_user_id, meal_type, meal_date, ...item } = row;
    return {
      item,
      meal: { id: item.meal_id, user_id: meal_user_id, type: meal_type, date: meal_date, time: null } as MealRow,
    };
  }

  async addItem(mealId: string, input: AddItemInput): Promise<MealItemRow> {
    const { rows } = await this.pool.query<MealItemRow>(
      `INSERT INTO meal_items (meal_id, food_id, custom_name, custom_nutrients, grams)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [mealId, input.foodId ?? null, input.customName ?? null, input.customNutrients ? JSON.stringify(input.customNutrients) : null, input.grams],
    );
    return rows[0];
  }

  async updateItemGrams(itemId: string, grams: number): Promise<MealItemRow | null> {
    const { rows } = await this.pool.query<MealItemRow>('UPDATE meal_items SET grams = $1 WHERE id = $2 RETURNING *', [
      grams,
      itemId,
    ]);
    return rows[0] ?? null;
  }

  async deleteItem(itemId: string): Promise<void> {
    await this.pool.query('DELETE FROM meal_items WHERE id = $1', [itemId]);
  }
}
