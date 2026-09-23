import { Pool } from 'pg';
import { ExerciseRow, ExerciseSearchParams, FavoriteRow, PagedResult } from './exercise.model';

export class ExerciseRepository {
  constructor(private readonly pool: Pool) {}

  async findById(id: string): Promise<ExerciseRow | null> {
    const { rows } = await this.pool.query<ExerciseRow>('SELECT * FROM exercises WHERE id = $1', [id]);
    return rows[0] ?? null;
  }

  /** Пакетная загрузка по id — для отдачи избранного/истории одним запросом вместо N. */
  async findByIds(ids: string[]): Promise<ExerciseRow[]> {
    if (ids.length === 0) return [];
    const { rows } = await this.pool.query<ExerciseRow>('SELECT * FROM exercises WHERE id = ANY($1::uuid[])', [ids]);
    return rows;
  }

  async search(params: ExerciseSearchParams): Promise<PagedResult<ExerciseRow>> {
    const conditions: string[] = [];
    const values: unknown[] = [];
    let i = 1;

    if (params.muscleGroup) {
      conditions.push(`muscle_group = $${i++}`);
      values.push(params.muscleGroup);
    }
    if (params.equipment) {
      conditions.push(`equipment = $${i++}`);
      values.push(params.equipment);
    }
    if (params.difficulty) {
      conditions.push(`difficulty = $${i++}`);
      values.push(params.difficulty);
    }
    if (params.query) {
      conditions.push(`name ILIKE '%' || $${i++} || '%'`);
      values.push(params.query);
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const countResult = await this.pool.query<{ count: string }>(`SELECT COUNT(*) FROM exercises ${where}`, values);
    const total = Number(countResult.rows[0]?.count ?? 0);

    const limit = params.perPage;
    const offset = (params.page - 1) * params.perPage;
    values.push(limit, offset);

    const { rows } = await this.pool.query<ExerciseRow>(
      `SELECT * FROM exercises ${where} ORDER BY name ASC LIMIT $${i++} OFFSET $${i}`,
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

  async addFavorite(userId: string, exerciseId: string): Promise<void> {
    await this.pool.query(
      `INSERT INTO exercise_favorites (user_id, exercise_id) VALUES ($1, $2)
       ON CONFLICT (user_id, exercise_id) DO NOTHING`,
      [userId, exerciseId],
    );
  }

  async removeFavorite(userId: string, exerciseId: string): Promise<void> {
    await this.pool.query('DELETE FROM exercise_favorites WHERE user_id = $1 AND exercise_id = $2', [userId, exerciseId]);
  }

  async listFavoriteIds(userId: string): Promise<string[]> {
    const { rows } = await this.pool.query<{ exercise_id: string }>(
      'SELECT exercise_id FROM exercise_favorites WHERE user_id = $1',
      [userId],
    );
    return rows.map((r) => r.exercise_id);
  }

  async isFavorite(userId: string, exerciseId: string): Promise<boolean> {
    const { rows } = await this.pool.query<FavoriteRow>(
      'SELECT id FROM exercise_favorites WHERE user_id = $1 AND exercise_id = $2',
      [userId, exerciseId],
    );
    return rows.length > 0;
  }
}
