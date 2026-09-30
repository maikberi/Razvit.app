import { Pool } from 'pg';
import { WorkoutProfilePatch, WorkoutProfileRow } from './workoutProfile.model';

export class WorkoutProfileRepository {
  constructor(private readonly pool: Pool) {}

  async find(userId: string): Promise<WorkoutProfileRow | null> {
    const { rows } = await this.pool.query<WorkoutProfileRow>('SELECT * FROM workout_profiles WHERE user_id = $1', [
      userId,
    ]);
    return rows[0] ?? null;
  }

  /**
   * Частичное обновление, слитое с уже сохранёнными значениями — как и
   * nutrition_profiles, анкета заполняется постепенно (см.
   * NutritionProfileRepository.upsert). equipment — единственное
   * массив-поле: раз пользователь его прислал, значит это его актуальный
   * полный набор оборудования, поэтому COALESCE на уровне всей колонки
   * (не мержим элементы), а не на уровне отдельных элементов массива.
   */
  async upsert(userId: string, patch: WorkoutProfilePatch): Promise<WorkoutProfileRow> {
    const { rows } = await this.pool.query<WorkoutProfileRow>(
      `INSERT INTO workout_profiles (user_id, experience, place, equipment, workouts_per_week, duration)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (user_id) DO UPDATE SET
         experience = COALESCE(EXCLUDED.experience, workout_profiles.experience),
         place = COALESCE(EXCLUDED.place, workout_profiles.place),
         equipment = COALESCE(EXCLUDED.equipment, workout_profiles.equipment),
         workouts_per_week = COALESCE(EXCLUDED.workouts_per_week, workout_profiles.workouts_per_week),
         duration = COALESCE(EXCLUDED.duration, workout_profiles.duration)
       RETURNING *`,
      [
        userId,
        patch.experience ?? null,
        patch.place ?? null,
        patch.equipment ?? null,
        patch.workoutsPerWeek ?? null,
        patch.duration ?? null,
      ],
    );
    return rows[0];
  }
}
