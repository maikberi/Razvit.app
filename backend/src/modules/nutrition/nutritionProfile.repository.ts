import { Pool } from 'pg';
import { NutritionProfilePatch, NutritionProfileRow } from './nutritionProfile.model';

export class NutritionProfileRepository {
  constructor(private readonly pool: Pool) {}

  async find(userId: string): Promise<NutritionProfileRow | null> {
    const { rows } = await this.pool.query<NutritionProfileRow>(
      'SELECT * FROM nutrition_profiles WHERE user_id = $1',
      [userId],
    );
    return rows[0] ?? null;
  }

  /**
   * Частичное обновление, слитое с уже сохранёнными значениями — profile
   * заполняется постепенно (не обязательно все поля разом), поэтому
   * COALESCE(new, old) на каждом поле, а не полная перезапись строки.
   */
  async upsert(userId: string, patch: NutritionProfilePatch): Promise<NutritionProfileRow> {
    const { rows } = await this.pool.query<NutritionProfileRow>(
      `INSERT INTO nutrition_profiles (user_id, sex, age, height_cm, weight_kg, activity_level, goal)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (user_id) DO UPDATE SET
         sex = COALESCE(EXCLUDED.sex, nutrition_profiles.sex),
         age = COALESCE(EXCLUDED.age, nutrition_profiles.age),
         height_cm = COALESCE(EXCLUDED.height_cm, nutrition_profiles.height_cm),
         weight_kg = COALESCE(EXCLUDED.weight_kg, nutrition_profiles.weight_kg),
         activity_level = COALESCE(EXCLUDED.activity_level, nutrition_profiles.activity_level),
         goal = COALESCE(EXCLUDED.goal, nutrition_profiles.goal)
       RETURNING *`,
      [
        userId,
        patch.sex ?? null,
        patch.age ?? null,
        patch.heightCm ?? null,
        patch.weightKg ?? null,
        patch.activityLevel ?? null,
        patch.goal ?? null,
      ],
    );
    return rows[0];
  }
}
