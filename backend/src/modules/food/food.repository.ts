import { Pool, PoolClient } from 'pg';
import { AliasRow, CreateFoodInput, FoodRow, MicronutrientRow, PagedResult, SearchParams } from './food.model';
import { normalizeName } from './food.normalize';

const SORTABLE_COLUMNS = new Set(['name', 'calories', 'protein', 'created_at', 'updated_at']);

function parseSort(sort: string): { column: string; direction: 'ASC' | 'DESC' } {
  const desc = sort.startsWith('-');
  const column = desc ? sort.slice(1) : sort;
  if (!SORTABLE_COLUMNS.has(column)) {
    return { column: 'name', direction: 'ASC' };
  }
  return { column, direction: desc ? 'DESC' : 'ASC' };
}

export class FoodRepository {
  constructor(private readonly pool: Pool) {}

  async create(input: CreateFoodInput, client?: PoolClient): Promise<FoodRow> {
    const db = client ?? this.pool;
    const normalized = normalizeName(input.name);
    const { rows } = await db.query<FoodRow>(
      `INSERT INTO foods
        (name, normalized_name, brand, barcode, category, source, source_id, basis_unit,
         calories, protein, fat, carbohydrates, fiber, sugar, sodium,
         serving_size, serving_unit, verified)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
       RETURNING *`,
      [
        input.name,
        normalized,
        input.brand ?? null,
        input.barcode ?? null,
        input.category ?? null,
        input.source,
        input.sourceId ?? null,
        input.basisUnit,
        input.calories,
        input.protein,
        input.fat,
        input.carbohydrates,
        input.fiber ?? 0,
        input.sugar ?? null,
        input.sodium ?? null,
        input.servingSize ?? null,
        input.servingUnit ?? null,
        input.verified ?? false,
      ],
    );
    const food = rows[0];

    if (input.micronutrients?.length) {
      for (const m of input.micronutrients) {
        await db.query(
          `INSERT INTO food_micronutrients (food_id, key, amount, unit) VALUES ($1,$2,$3,$4)
           ON CONFLICT (food_id, key) DO UPDATE SET amount = EXCLUDED.amount, unit = EXCLUDED.unit`,
          [food.id, m.key, m.amount, m.unit],
        );
      }
    }
    if (input.aliases?.length) {
      for (const alias of input.aliases) {
        await db.query(
          `INSERT INTO food_aliases (food_id, alias, normalized_alias) VALUES ($1,$2,$3)
           ON CONFLICT (food_id, normalized_alias) DO NOTHING`,
          [food.id, alias, normalizeName(alias)],
        );
      }
    }
    return food;
  }

  async update(id: string, patch: Partial<CreateFoodInput>, client?: PoolClient): Promise<FoodRow | null> {
    const db = client ?? this.pool;
    const fields: string[] = [];
    const values: unknown[] = [];
    let i = 1;

    const map: Record<string, unknown> = {
      name: patch.name,
      normalized_name: patch.name != null ? normalizeName(patch.name) : undefined,
      brand: patch.brand,
      barcode: patch.barcode,
      category: patch.category,
      basis_unit: patch.basisUnit,
      calories: patch.calories,
      protein: patch.protein,
      fat: patch.fat,
      carbohydrates: patch.carbohydrates,
      fiber: patch.fiber,
      sugar: patch.sugar,
      sodium: patch.sodium,
      serving_size: patch.servingSize,
      serving_unit: patch.servingUnit,
      verified: patch.verified,
    };

    for (const [column, value] of Object.entries(map)) {
      if (value === undefined) continue;
      fields.push(`${column} = $${i++}`);
      values.push(value);
    }
    if (fields.length === 0) return this.findById(id);

    values.push(id);
    const { rows } = await db.query<FoodRow>(
      `UPDATE foods SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
      values,
    );
    return rows[0] ?? null;
  }

  async findById(id: string): Promise<FoodRow | null> {
    const { rows } = await this.pool.query<FoodRow>('SELECT * FROM foods WHERE id = $1', [id]);
    return rows[0] ?? null;
  }

  async findByBarcode(barcode: string): Promise<FoodRow | null> {
    const { rows } = await this.pool.query<FoodRow>('SELECT * FROM foods WHERE barcode = $1', [barcode]);
    return rows[0] ?? null;
  }

  async findBySource(source: string, sourceId: string): Promise<FoodRow | null> {
    const { rows } = await this.pool.query<FoodRow>(
      'SELECT * FROM foods WHERE source = $1 AND source_id = $2',
      [source, sourceId],
    );
    return rows[0] ?? null;
  }

  /** Приблизительное совпадение по названию+бренду — для кросс-источниковой дедупликации. */
  async findSimilar(name: string, brand: string | null, threshold = 0.92): Promise<FoodRow | null> {
    const normalized = normalizeName(name);
    const { rows } = await this.pool.query<FoodRow>(
      `SELECT *, similarity(normalized_name, $1) AS sim
       FROM foods
       WHERE normalized_name % $1
         AND ($2::text IS NULL OR brand IS NOT DISTINCT FROM $2)
       ORDER BY sim DESC
       LIMIT 1`,
      [normalized, brand],
    );
    const row = rows[0] as (FoodRow & { sim: number }) | undefined;
    if (!row || row.sim < threshold) return null;
    return row;
  }

  async getMicronutrients(foodId: string): Promise<MicronutrientRow[]> {
    const { rows } = await this.pool.query<MicronutrientRow>(
      'SELECT * FROM food_micronutrients WHERE food_id = $1 ORDER BY key',
      [foodId],
    );
    return rows;
  }

  async getAliases(foodId: string): Promise<AliasRow[]> {
    const { rows } = await this.pool.query<AliasRow>('SELECT * FROM food_aliases WHERE food_id = $1', [foodId]);
    return rows;
  }

  async search(params: SearchParams): Promise<PagedResult<FoodRow>> {
    const { column, direction } = parseSort(params.sort);
    const conditions: string[] = [];
    const values: unknown[] = [];
    let i = 1;

    if (params.barcode) {
      conditions.push(`barcode = $${i++}`);
      values.push(params.barcode);
    }
    if (params.category) {
      conditions.push(`category = $${i++}`);
      values.push(params.category);
    }
    if (params.source) {
      conditions.push(`source = $${i++}`);
      values.push(params.source);
    }

    let rankSelect = '';
    let orderBy = `ORDER BY ${column} ${direction}`;
    if (params.query) {
      const normalized = normalizeName(params.query);
      const qIdx = i++;
      values.push(normalized);
      conditions.push(
        `(normalized_name % $${qIdx}
          OR normalized_name ILIKE '%' || $${qIdx} || '%'
          OR brand ILIKE '%' || $${qIdx} || '%'
          OR EXISTS (SELECT 1 FROM food_aliases fa WHERE fa.food_id = foods.id AND fa.normalized_alias % $${qIdx}))`,
      );
      rankSelect = `, similarity(normalized_name, $${qIdx}) AS rank`;
      orderBy = 'ORDER BY rank DESC, name ASC';
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const countResult = await this.pool.query<{ count: string }>(
      `SELECT COUNT(*) FROM foods ${where}`,
      values,
    );
    const total = Number(countResult.rows[0]?.count ?? 0);

    const limit = params.perPage;
    const offset = (params.page - 1) * params.perPage;
    values.push(limit, offset);

    const { rows } = await this.pool.query<FoodRow>(
      `SELECT foods.* ${rankSelect} FROM foods ${where} ${orderBy} LIMIT $${i++} OFFSET $${i}`,
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
}
