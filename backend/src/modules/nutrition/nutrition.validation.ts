import { z } from 'zod';

const micronutrientValueSchema = z.object({
  amount: z.number(),
  unit: z.string().min(1),
});

const nutrientSourceSchema = z.object({
  calories: z.number().min(0),
  protein: z.number().min(0),
  fat: z.number().min(0),
  carbohydrates: z.number().min(0),
  fiber: z.number().min(0).default(0),
  sugar: z.number().min(0).nullable().optional().default(null),
  sodium: z.number().min(0).nullable().optional().default(null),
  micronutrients: z.record(z.string(), micronutrientValueSchema).optional(),
});

const foodAmountInputSchema = z
  .object({
    foodId: z.string().uuid().optional(),
    nutrients: nutrientSourceSchema.optional(),
    grams: z.number().min(0, 'grams must be >= 0'),
  })
  .refine((v) => Boolean(v.foodId) !== Boolean(v.nutrients), {
    message: 'Provide exactly one of foodId or nutrients',
  });

export const calculateFoodSchema = foodAmountInputSchema;

export const calculateMealSchema = z.object({
  items: z.array(foodAmountInputSchema).min(1, 'items must contain at least one entry'),
});

export const calculateRecipeSchema = z.object({
  items: z.array(foodAmountInputSchema).min(1, 'items must contain at least one entry'),
  servings: z.number().positive('servings must be > 0').default(1),
});

export const calculateDaySchema = z.object({
  meals: z
    .array(z.object({ items: z.array(foodAmountInputSchema).min(1) }))
    .min(1, 'meals must contain at least one meal'),
});

const nutrientProfileSchema = z.object({
  calories: z.number(),
  protein: z.number(),
  fat: z.number(),
  carbohydrates: z.number(),
  fiber: z.number(),
  sugar: z.number().nullable(),
  sodium: z.number().nullable(),
  micronutrients: z.record(z.string(), micronutrientValueSchema).default({}),
});

export const calculateWeekSchema = z.object({
  days: z.array(nutrientProfileSchema).min(1, 'days must contain at least one day'),
});

export type CalculateFoodBody = z.infer<typeof calculateFoodSchema>;
export type CalculateMealBody = z.infer<typeof calculateMealSchema>;
export type CalculateRecipeBody = z.infer<typeof calculateRecipeSchema>;
export type CalculateDayBody = z.infer<typeof calculateDaySchema>;
export type CalculateWeekBody = z.infer<typeof calculateWeekSchema>;

export const dateQuerySchema = z.object({
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD')
    .optional(),
});

export const updateTargetsSchema = z.object({
  title: z.string().min(1).optional(),
  calorieGoal: z.number().int().min(0),
  proteinGoal: z.number().int().min(0),
  fatGoal: z.number().int().min(0),
  carbsGoal: z.number().int().min(0),
  waterGoalMl: z.number().int().min(0),
});

export const addWaterSchema = z.object({
  amountMl: z.number().int().positive('amountMl must be > 0'),
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD')
    .optional(),
});

export const removeLastWaterQuerySchema = dateQuerySchema;

export type DateQuery = z.infer<typeof dateQuerySchema>;
export type UpdateTargetsBody = z.infer<typeof updateTargetsSchema>;
export type AddWaterBody = z.infer<typeof addWaterSchema>;
