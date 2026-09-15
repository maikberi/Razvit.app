import { Pool } from 'pg';

export interface TargetsRow {
  user_id: string;
  title: string;
  calorie_goal: number;
  protein_goal: number;
  fat_goal: number;
  carbs_goal: number;
  water_goal_ml: number;
  created_at: Date;
  updated_at: Date;
}

const DEFAULT_TARGETS = {
  title: 'Персональный план',
  calorieGoal: 2300,
  proteinGoal: 160,
  fatGoal: 70,
  carbsGoal: 280,
  waterGoalMl: 2500,
};

export class NutritionTargetsRepository {
  constructor(private readonly pool: Pool) {}

  async find(userId: string): Promise<TargetsRow | null> {
    const { rows } = await this.pool.query<TargetsRow>('SELECT * FROM nutrition_targets WHERE user_id = $1', [userId]);
    return rows[0] ?? null;
  }

  /** Первое обращение нового пользователя — создаёт разумные значения по умолчанию. */
  async getOrCreateDefault(userId: string): Promise<TargetsRow> {
    const existing = await this.find(userId);
    if (existing) return existing;
    const { rows } = await this.pool.query<TargetsRow>(
      `INSERT INTO nutrition_targets (user_id, title, calorie_goal, protein_goal, fat_goal, carbs_goal, water_goal_ml)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        userId,
        DEFAULT_TARGETS.title,
        DEFAULT_TARGETS.calorieGoal,
        DEFAULT_TARGETS.proteinGoal,
        DEFAULT_TARGETS.fatGoal,
        DEFAULT_TARGETS.carbsGoal,
        DEFAULT_TARGETS.waterGoalMl,
      ],
    );
    return rows[0];
  }

  async upsert(
    userId: string,
    patch: { title?: string; calorieGoal: number; proteinGoal: number; fatGoal: number; carbsGoal: number; waterGoalMl: number },
  ): Promise<TargetsRow> {
    const { rows } = await this.pool.query<TargetsRow>(
      `INSERT INTO nutrition_targets (user_id, title, calorie_goal, protein_goal, fat_goal, carbs_goal, water_goal_ml)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (user_id) DO UPDATE SET
         title = EXCLUDED.title, calorie_goal = EXCLUDED.calorie_goal, protein_goal = EXCLUDED.protein_goal,
         fat_goal = EXCLUDED.fat_goal, carbs_goal = EXCLUDED.carbs_goal, water_goal_ml = EXCLUDED.water_goal_ml
       RETURNING *`,
      [userId, patch.title ?? DEFAULT_TARGETS.title, patch.calorieGoal, patch.proteinGoal, patch.fatGoal, patch.carbsGoal, patch.waterGoalMl],
    );
    return rows[0];
  }
}
