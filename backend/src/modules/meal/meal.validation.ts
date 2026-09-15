import { z } from 'zod';
import { MEAL_TYPES } from './meal.model';

export const dateQuerySchema = z.object({
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD')
    .optional(),
});

const nutrientsSchema = z.object({
  calories: z.number().min(0),
  protein: z.number().min(0),
  fat: z.number().min(0),
  carbohydrates: z.number().min(0),
  fiber: z.number().min(0).optional(),
  sugar: z.number().min(0).nullable().optional(),
  sodium: z.number().min(0).nullable().optional(),
});

export const addMealItemSchema = z
  .object({
    foodId: z.string().uuid().optional(),
    name: z.string().min(1).optional(),
    nutrients: nutrientsSchema.optional(),
    grams: z.number().positive('grams must be > 0'),
  })
  .refine((v) => Boolean(v.foodId) !== Boolean(v.nutrients), {
    message: 'Provide exactly one of foodId or nutrients',
  })
  .refine((v) => v.foodId || v.name, { message: 'name is required for manual entries' });

export const updateMealItemSchema = z.object({
  grams: z.number().positive('grams must be > 0'),
});

export const mealIdParamSchema = z.object({ id: z.string().uuid() });
export const mealItemIdParamSchema = z.object({ id: z.string().uuid() });

export type AddMealItemBody = z.infer<typeof addMealItemSchema>;
export type UpdateMealItemBody = z.infer<typeof updateMealItemSchema>;
export type DateQuery = z.infer<typeof dateQuerySchema>;

export { MEAL_TYPES };
