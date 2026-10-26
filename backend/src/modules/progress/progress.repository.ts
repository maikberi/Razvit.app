import { Pool } from 'pg';
import { WeightEntryRow } from './progress.model';

export class ProgressRepository {
  constructor(private readonly pool: Pool) {}

  async addWeightEntry(userId: string, weightKg: number, loggedAt?: Date): Promise<WeightEntryRow> {
    const { rows } = await this.pool.query<WeightEntryRow>(
      `INSERT INTO weight_entries (user_id, weight_kg, logged_at)
       VALUES ($1, $2, COALESCE($3, now()))
       RETURNING *`,
      [userId, weightKg, loggedAt ?? null],
    );
    return rows[0];
  }

  async listWeightEntries(userId: string): Promise<WeightEntryRow[]> {
    const { rows } = await this.pool.query<WeightEntryRow>(
      'SELECT * FROM weight_entries WHERE user_id = $1 ORDER BY logged_at ASC',
      [userId],
    );
    return rows;
  }

  async findWeightEntry(userId: string, id: string): Promise<WeightEntryRow | null> {
    const { rows } = await this.pool.query<WeightEntryRow>(
      'SELECT * FROM weight_entries WHERE id = $1 AND user_id = $2',
      [id, userId],
    );
    return rows[0] ?? null;
  }

  async deleteWeightEntry(userId: string, id: string): Promise<void> {
    await this.pool.query('DELETE FROM weight_entries WHERE id = $1 AND user_id = $2', [id, userId]);
  }
}
