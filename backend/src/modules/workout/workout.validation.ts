import { z } from 'zod';
import { DURATION_VALUES, EXPERIENCE_VALUES, PLACE_VALUES } from './workoutProfile.model';

const GOALS = ['mass', 'loss', 'strength', 'definition', 'maintenance'] as const;
const LEVELS = ['beginner', 'intermediate', 'advanced'] as const;
const STATUSES = ['done', 'planned', 'missed'] as const;

export const updateWorkoutProfileSchema = z.object({
  experience: z.enum(EXPERIENCE_VALUES).optional(),
  place: z.enum(PLACE_VALUES).optional(),
  // Свободные строки (имена HomeEquipment во Flutter), не enum — см.
  // WorkoutProfileRow.equipment в workoutProfile.model.ts.
  equipment: z.array(z.string().trim().min(1)).optional(),
  workoutsPerWeek: z.coerce.number().int().min(1).max(7).optional(),
  duration: z.enum(DURATION_VALUES).optional(),
});
export type UpdateWorkoutProfileBody = z.infer<typeof updateWorkoutProfileSchema>;

const programExerciseSchema = z.object({
  exerciseId: z.string().trim().min(1),
  exerciseName: z.string().trim().min(1),
  sets: z.coerce.number().int().min(1).max(20),
  repsLabel: z.string().trim().min(1),
  weightKg: z.coerce.number().min(0).max(500),
  restSeconds: z.coerce.number().int().min(0).max(1800),
});

const programDaySchema = z.object({
  id: z.string().trim().min(1),
  title: z.string().trim().min(1),
  exercises: z.array(programExerciseSchema).min(1),
});

export const createProgramSchema = z.object({
  title: z.string().trim().min(1).max(80),
  goal: z.enum(GOALS),
  level: z.enum(LEVELS),
  totalWeeks: z.coerce.number().int().min(1).max(52).default(8),
  trainingDays: z.array(z.coerce.number().int().min(1).max(7)).default([]),
  days: z.array(programDaySchema).min(1),
});
export type CreateProgramBody = z.infer<typeof createProgramSchema>;

export const programIdParamSchema = z.object({
  id: z.string().uuid('id must be a valid UUID'),
});

const setLogSchema = z.object({
  weightKg: z.coerce.number().min(0).max(500),
  reps: z.coerce.number().int().min(0).max(200),
  completed: z.boolean().default(true),
});

const exerciseLogSchema = z.object({
  exerciseId: z.string().trim().min(1),
  exerciseName: z.string().trim().min(1),
  comment: z.string().trim().min(1).nullable().optional(),
  sets: z.array(setLogSchema).default([]),
});

export const createSessionSchema = z.object({
  programId: z.string().uuid().optional(),
  programDayId: z.string().trim().min(1).optional(),
  date: z.coerce.date(),
  title: z.string().trim().min(1).max(120),
  status: z.enum(STATUSES).default('done'),
  durationMinutes: z.coerce.number().int().min(0).max(1000).default(0),
  calories: z.coerce.number().int().min(0).max(10000).default(0),
  exerciseLogs: z.array(exerciseLogSchema).default([]),
});
export type CreateSessionBody = z.infer<typeof createSessionSchema>;
