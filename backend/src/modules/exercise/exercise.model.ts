export type MuscleGroup = 'chest' | 'back' | 'legs' | 'shoulders' | 'arms' | 'abs' | 'cardio';
export type ExerciseDifficulty = 'beginner' | 'intermediate' | 'advanced';
export type ExerciseSource = 'RAZVIT' | 'EXTERNAL';

/** Строка таблицы exercises как она лежит в БД. */
export interface ExerciseRow {
  id: string;
  slug: string;
  name: string;
  muscle_group: MuscleGroup;
  secondary_muscles: string[];
  equipment: string;
  difficulty: ExerciseDifficulty;
  instructions: string[];
  gif_url: string | null;
  thumb_url: string | null;
  source: ExerciseSource;
  created_at: Date;
  updated_at: Date;
}

export interface ExerciseSearchParams {
  query?: string;
  muscleGroup?: MuscleGroup;
  equipment?: string;
  difficulty?: ExerciseDifficulty;
  page: number;
  perPage: number;
}

export interface PagedResult<T> {
  items: T[];
  page: number;
  perPage: number;
  total: number;
  totalPages: number;
}

export interface FavoriteRow {
  id: string;
  user_id: string;
  exercise_id: string;
  created_at: Date;
}
