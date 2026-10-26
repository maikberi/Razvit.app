import { WorkoutProgramRow, WorkoutSessionRow } from './workout.model';

export interface WorkoutProgramDTO {
  id: string;
  title: string;
  goal: string;
  level: string;
  totalWeeks: number;
  trainingDays: number[];
  days: unknown;
  isCustom: boolean;
}

export function serializeProgram(row: WorkoutProgramRow): WorkoutProgramDTO {
  return {
    id: row.id,
    title: row.title,
    goal: row.goal,
    level: row.level,
    totalWeeks: row.total_weeks,
    trainingDays: row.training_days,
    days: row.days,
    isCustom: true,
  };
}

export interface WorkoutSessionDTO {
  id: string;
  programId: string | null;
  programDayId: string | null;
  date: string;
  title: string;
  status: string;
  durationMinutes: number;
  calories: number;
  exerciseLogs: unknown;
}

export function serializeSession(row: WorkoutSessionRow): WorkoutSessionDTO {
  return {
    id: row.id,
    programId: row.program_id,
    programDayId: row.program_day_id,
    date: row.date.toISOString(),
    title: row.title,
    status: row.status,
    durationMinutes: row.duration_minutes,
    calories: row.calories,
    exerciseLogs: row.exercise_logs,
  };
}
