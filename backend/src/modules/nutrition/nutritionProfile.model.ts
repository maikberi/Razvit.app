export const SEX_VALUES = ['male', 'female'] as const;
export type Sex = (typeof SEX_VALUES)[number];

// Стандартная 5-ступенчатая шкала множителя активности для TDEE (Harris/
// Mifflin-style): sedentary (почти без движения) -> very_active (физический
// труд/спорт каждый день). Не путать с ExperienceLevel во Flutter-онбординге
// (beginner/intermediate/advanced) — это уровень ОПЫТА в тренировках, а
// не то, сколько человек двигается в течение дня; для BMR/TDEE нужно
// именно второе, поэтому это отдельное поле.
export const ACTIVITY_LEVEL_VALUES = ['sedentary', 'light', 'moderate', 'active', 'very_active'] as const;
export type ActivityLevel = (typeof ACTIVITY_LEVEL_VALUES)[number];

// Те же 6 значений, что и FitnessGoal во Flutter-онбординге (в snake_case
// для API) — сознательно не создаём отдельный "калорийный" enum, чтобы не
// плодить два разных представления одного и того же выбора пользователя.
export const NUTRITION_GOAL_VALUES = [
  'lose_weight',
  'gain_muscle',
  'get_stronger',
  'improve_shape',
  'endurance',
  'maintain',
] as const;
export type NutritionGoal = (typeof NUTRITION_GOAL_VALUES)[number];

export interface NutritionProfileRow {
  user_id: string;
  sex: Sex | null;
  age: number | null;
  height_cm: string | null; // numeric приходит из pg как строка
  weight_kg: string | null;
  activity_level: ActivityLevel | null;
  goal: NutritionGoal | null;
  created_at: Date;
  updated_at: Date;
}

export interface NutritionProfilePatch {
  sex?: Sex | null;
  age?: number | null;
  heightCm?: number | null;
  weightKg?: number | null;
  activityLevel?: ActivityLevel | null;
  goal?: NutritionGoal | null;
}

/** Профиль, приведённый к нужным для расчёта типам — все поля обязательны (см. NutritionTargetService.isComplete). */
export interface CompleteNutritionProfile {
  sex: Sex;
  age: number;
  heightCm: number;
  weightKg: number;
  activityLevel: ActivityLevel;
  goal: NutritionGoal;
}
