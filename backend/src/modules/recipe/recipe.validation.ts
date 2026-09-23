import { z } from 'zod';

// query-параметры всегда строки — 'false' в булевой схеме zod без preprocess
// была бы truthy (непустая строка). Явно разбираем 'true'/'false'.
const boolQueryParam = z.preprocess((v) => {
  if (v === 'true') return true;
  if (v === 'false') return false;
  return v;
}, z.boolean().optional());

export const recipeIngredientSchema = z.object({
  foodId: z.string().uuid('foodId must be a valid UUID'),
  quantity: z.number().positive('quantity must be > 0'),
  unit: z.enum(['g', 'ml', 'pcs']),
});

export const recipeInputSchema = z.object({
  name: z.string().trim().min(1, 'name is required').max(200),
  description: z.string().trim().max(2000).nullable().optional(),
  imageUrl: z.string().trim().max(2000).nullable().optional(),
  servings: z.number().positive('servings must be > 0'),
  cookingTimeMinutes: z.number().int().min(0).nullable().optional(),
  instructions: z.string().trim().min(1, 'instructions is required'),
  ingredients: z.array(recipeIngredientSchema).min(1, 'recipe must contain at least one ingredient'),
});

export const recipeIdParamSchema = z.object({
  id: z.string().uuid('id must be a valid UUID'),
});

export const recipeSearchQuerySchema = z.object({
  q: z.string().trim().min(1).optional(),
  mine: boolQueryParam,
  favoriteOnly: boolQueryParam,
  page: z.coerce.number().int().min(1).default(1),
  perPage: z.coerce.number().int().min(1).max(100).default(20),
});

export type RecipeInputBody = z.infer<typeof recipeInputSchema>;
export type RecipeSearchQuery = z.infer<typeof recipeSearchQuerySchema>;
