// Те же значения, что ExperienceLevel/TrainingPlace/WorkoutDuration в
// Flutter-онбординге (см. lib/data/models/user.dart) — сознательно
// отдельные типы (backend не должен зависеть от Flutter-энамов), но с тем
// же смыслом.
export const EXPERIENCE_VALUES = ['beginner', 'intermediate', 'advanced'] as const;
export type Experience = (typeof EXPERIENCE_VALUES)[number];

export const PLACE_VALUES = ['gym', 'home', 'outdoor', 'mixed'] as const;
export type Place = (typeof PLACE_VALUES)[number];

export const DURATION_VALUES = ['short', 'medium', 'long', 'extended', 'veryLong'] as const;
export type Duration = (typeof DURATION_VALUES)[number];

// Имена значений HomeEquipment во Flutter (dumbbells/pullUpBar/bands/
// barbell/mat/other/none) — здесь просто свободные строки без CHECK:
// список экипировки не обязан быть исчерпывающим прямо сейчас, а генератор
// программы (workoutProgramGenerator.service.ts) сам игнорирует
// нераспознанные значения вместо того, чтобы отвергать весь профиль.
export interface WorkoutProfileRow {
  user_id: string;
  experience: Experience | null;
  place: Place | null;
  equipment: string[] | null;
  workouts_per_week: number | null;
  duration: Duration | null;
  created_at: Date;
  updated_at: Date;
}

export interface WorkoutProfilePatch {
  experience?: Experience | null;
  place?: Place | null;
  equipment?: string[] | null;
  workoutsPerWeek?: number | null;
  duration?: Duration | null;
}

/** Профиль, приведённый к нужным для генерации типам — все поля обязательны. */
export interface CompleteWorkoutProfile {
  experience: Experience;
  place: Place;
  equipment: string[];
  workoutsPerWeek: number;
  duration: Duration;
}
