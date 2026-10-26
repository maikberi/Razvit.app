export type ProgramGoal = 'mass' | 'loss' | 'strength' | 'definition' | 'maintenance';
export type ProgramLevel = 'beginner' | 'intermediate' | 'advanced';
export type SessionStatus = 'done' | 'planned' | 'missed';

/** Плановое упражнение внутри дня программы — как ProgramExercise во Flutter. */
export interface ProgramExerciseJson {
  exerciseId: string;
  exerciseName: string;
  sets: number;
  repsLabel: string;
  weightKg: number;
  restSeconds: number;
}

/** Тренировочный день программы — как WorkoutDay во Flutter. */
export interface ProgramDayJson {
  id: string;
  title: string;
  exercises: ProgramExerciseJson[];
}

export interface WorkoutProgramRow {
  id: string;
  user_id: string;
  title: string;
  goal: ProgramGoal;
  level: ProgramLevel;
  total_weeks: number;
  training_days: number[];
  days: ProgramDayJson[];
  created_at: Date;
  updated_at: Date;
}

/** Один зафиксированный подход — как SetLog во Flutter. */
export interface SetLogJson {
  weightKg: number;
  reps: number;
  completed: boolean;
}

/** Подходы по одному упражнению за тренировку — как ExerciseLog во Flutter. */
export interface ExerciseLogJson {
  exerciseId: string;
  exerciseName: string;
  comment: string | null;
  sets: SetLogJson[];
}

export interface WorkoutSessionRow {
  id: string;
  user_id: string;
  program_id: string | null;
  program_day_id: string | null;
  date: Date;
  title: string;
  status: SessionStatus;
  duration_minutes: number;
  calories: number;
  exercise_logs: ExerciseLogJson[];
  created_at: Date;
}
