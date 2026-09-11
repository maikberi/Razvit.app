import { Pool, PoolClient } from 'pg';
import { PagedResult } from '../food/food.model';
import { RecipeIngredientInput, RecipeIngredientRow, RecipeInput, RecipeRow, RecipeSearchParams } from './recipe.model';

export class RecipeRepository {
  constructor(private readonly pool: Pool) {}

  async withTransaction<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await fn(client);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async create(userId: string, input: RecipeInput): Promise<{ recipe: RecipeRow; ingredients: RecipeIngredientRow[] }> {
    return this.withTransaction(async (client) => {
      const { rows } = await client.query<RecipeRow>(
        `INSERT INTO recipes (user_id, name, description, image_url, servings, cooking_time_minutes, instructions)
         VALUES ($1,$2,$3,$4,$5,$6,$7)
         RETURNING *`,
        [
          userId,
          input.name,
          input.description ?? null,
          input.imageUrl ?? null,
          input.servings,
          input.cookingTimeMinutes ?? null,
          input.instructions,
        ],
      );
      const recipe = rows[0];
      const ingredients = await this.replaceIngredients(client, recipe.id, input.ingredients);
      return { recipe, ingredients };
    });
  }

  /** Полная замена: сам рецепт (все поля) + ингредиенты целиком — проще и надёжнее, чем diff по одной строке. */
  async update(id: string, input: RecipeInput): Promise<{ recipe: RecipeRow; ingredients: RecipeIngredientRow[] } | null> {
    return this.withTransaction(async (client) => {
      const { rows } = await client.query<RecipeRow>(
        `UPDATE recipes
         SET name = $1, description = $2, image_url = $3, servings = $4, cooking_time_minutes = $5, instructions = $6
         WHERE id = $7
         RETURNING *`,
        [
          input.name,
          input.description ?? null,
          input.imageUrl ?? null,
          input.servings,
          input.cookingTimeMinutes ?? null,
          input.instructions,
          id,
        ],
      );
      const recipe = rows[0];
      if (!recipe) return null;
      const ingredients = await this.replaceIngredients(client, id, input.ingredients);
      return { recipe, ingredients };
    });
  }

  private async replaceIngredients(
    client: PoolClient,
    recipeId: string,
    items: RecipeIngredientInput[],
  ): Promise<RecipeIngredientRow[]> {
    await client.query('DELETE FROM recipe_ingredients WHERE recipe_id = $1', [recipeId]);
    const result: RecipeIngredientRow[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const { rows } = await client.query<RecipeIngredientRow>(
        `INSERT INTO recipe_ingredients (recipe_id, food_id, quantity, unit, position)
         VALUES ($1,$2,$3,$4,$5)
         RETURNING *`,
        [recipeId, item.foodId, item.quantity, item.unit, i],
      );
      result.push(rows[0]);
    }
    return result;
  }

  async findById(id: string): Promise<RecipeRow | null> {
    const { rows } = await this.pool.query<RecipeRow>('SELECT * FROM recipes WHERE id = $1', [id]);
    return rows[0] ?? null;
  }

  async delete(id: string): Promise<void> {
    await this.pool.query('DELETE FROM recipes WHERE id = $1', [id]);
  }

  async getIngredients(recipeId: string): Promise<RecipeIngredientRow[]> {
    const { rows } = await this.pool.query<RecipeIngredientRow>(
      'SELECT * FROM recipe_ingredients WHERE recipe_id = $1 ORDER BY position',
      [recipeId],
    );
    return rows;
  }

  /** Пакетная загрузка ингредиентов сразу для нескольких рецептов (список) — без N+1. */
  async getIngredientsForRecipes(recipeIds: string[]): Promise<RecipeIngredientRow[]> {
    if (recipeIds.length === 0) return [];
    const { rows } = await this.pool.query<RecipeIngredientRow>(
      'SELECT * FROM recipe_ingredients WHERE recipe_id = ANY($1::uuid[]) ORDER BY recipe_id, position',
      [recipeIds],
    );
    return rows;
  }

  async search(params: RecipeSearchParams): Promise<PagedResult<RecipeRow>> {
    const conditions: string[] = [];
    const values: unknown[] = [];
    let i = 1;
    let join = '';

    if (params.favoriteOnly) {
      join = `JOIN recipe_favorites rf ON rf.recipe_id = recipes.id AND rf.user_id = $${i++}`;
      values.push(params.userId);
    }
    if (params.mine) {
      conditions.push(`recipes.user_id = $${i++}`);
      values.push(params.userId);
    }
    if (params.q) {
      conditions.push(`recipes.name ILIKE '%' || $${i++} || '%'`);
      values.push(params.q);
    }
    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const countResult = await this.pool.query<{ count: string }>(
      `SELECT COUNT(*) FROM recipes ${join} ${where}`,
      values,
    );
    const total = Number(countResult.rows[0]?.count ?? 0);

    const limit = params.perPage;
    const offset = (params.page - 1) * params.perPage;
    values.push(limit, offset);

    const { rows } = await this.pool.query<RecipeRow>(
      `SELECT recipes.* FROM recipes ${join} ${where} ORDER BY recipes.created_at DESC LIMIT $${i++} OFFSET $${i}`,
      values,
    );

    return {
      items: rows,
      page: params.page,
      perPage: params.perPage,
      total,
      totalPages: Math.max(1, Math.ceil(total / params.perPage)),
    };
  }

  async isFavorite(userId: string, recipeId: string): Promise<boolean> {
    const { rows } = await this.pool.query(
      'SELECT 1 FROM recipe_favorites WHERE user_id = $1 AND recipe_id = $2',
      [userId, recipeId],
    );
    return rows.length > 0;
  }

  /** Пакетная проверка избранного сразу для списка рецептов — без N+1. */
  async favoritesForUser(userId: string, recipeIds: string[]): Promise<Set<string>> {
    if (recipeIds.length === 0) return new Set();
    const { rows } = await this.pool.query<{ recipe_id: string }>(
      'SELECT recipe_id FROM recipe_favorites WHERE user_id = $1 AND recipe_id = ANY($2::uuid[])',
      [userId, recipeIds],
    );
    return new Set(rows.map((r) => r.recipe_id));
  }

  async addFavorite(userId: string, recipeId: string): Promise<void> {
    await this.pool.query(
      'INSERT INTO recipe_favorites (user_id, recipe_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [userId, recipeId],
    );
  }

  async removeFavorite(userId: string, recipeId: string): Promise<void> {
    await this.pool.query('DELETE FROM recipe_favorites WHERE user_id = $1 AND recipe_id = $2', [userId, recipeId]);
  }
}
