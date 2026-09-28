import { z } from 'zod';

export const addWeightEntrySchema = z.object({
  weightKg: z.coerce.number().positive().max(500),
  loggedAt: z.coerce.date().optional(),
});
export type AddWeightEntryBody = z.infer<typeof addWeightEntrySchema>;

export const weightEntryIdParamSchema = z.object({
  id: z.string().uuid('id must be a valid UUID'),
});
