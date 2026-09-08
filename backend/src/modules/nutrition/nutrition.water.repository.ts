import { Pool } from 'pg';

export interface WaterEntryRow {
  id: string;
  user_id: string;
  date: string;
  amount_ml: number;
  logged_at: Date;
}

export class NutritionWaterRepository {
  constructor(private readonly pool: Pool) {}

  async getForDate(userId: string, date: string): Promise<WaterEntryRow[]> {
    const { rows } = await this.pool.query<WaterEntryRow>(
      'SELECT * FROM water_entries WHERE user_id = $1 AND date = $2 ORDER BY logged_at',
      [userId, date],
    );
    return rows;
  }

  async add(userId: string, date: string, amountMl: number): Promise<WaterEntryRow> {
    const { rows } = await this.pool.query<WaterEntryRow>(
      'INSERT INTO water_entries (user_id, date, amount_ml) VALUES ($1, $2, $3) RETURNING *',
      [userId, date, amountMl],
    );
    return rows[0];
  }

  /** Убрать последнюю добавленную запись за дату — для кнопки "отменить" в UI. */
  async deleteLast(userId: string, date: string): Promise<void> {
    await this.pool.query(
      `DELETE FROM water_entries WHERE id = (
         SELECT id FROM water_entries WHERE user_id = $1 AND date = $2 ORDER BY logged_at DESC LIMIT 1
       )`,
      [userId, date],
    );
  }
}
