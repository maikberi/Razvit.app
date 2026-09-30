import { z } from 'zod';

export const generateRecipeSchema = z.object({
  prompt: z.string().trim().min(3, 'prompt is required').max(500, 'prompt is too long'),
});

export type GenerateRecipeBody = z.infer<typeof generateRecipeSchema>;
