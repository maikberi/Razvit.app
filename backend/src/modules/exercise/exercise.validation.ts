import { z } from 'zod';

const MUSCLE_GROUPS = ['chest', 'back', 'legs', 'shoulders', 'arms', 'abs', 'cardio'] as const;
const DIFFICULTIES = ['beginner', 'intermediate', 'advanced'] as const;

export const searchQuerySchema = z.object({
  q: z.string().trim().min(1).optional(),
  muscleGroup: z.enum(MUSCLE_GROUPS).optional(),
  equipment: z.string().trim().min(1).optional(),
  difficulty: z.enum(DIFFICULTIES).optional(),
  page: z.coerce.number().int().min(1).default(1),
  perPage: z.coerce.number().int().min(1).max(100).default(20),
});
export type SearchQuery = z.infer<typeof searchQuerySchema>;

export const idParamSchema = z.object({
  id: z.string().uuid('id must be a valid UUID'),
});
