import { z } from 'zod';

export const createFoodSchema = z.object({
  name: z.string().trim().min(1, 'name is required').max(200),
  brand: z.string().trim().max(120).nullable().optional(),
  barcode: z.string().trim().max(64).nullable().optional(),
  category: z.string().trim().max(80).nullable().optional(),
  basisUnit: z.enum(['g', 'ml']).default('g'),
  calories: z.number().min(0, 'calories must be >= 0'),
  protein: z.number().min(0, 'protein must be >= 0'),
  fat: z.number().min(0, 'fat must be >= 0'),
  carbohydrates: z.number().min(0, 'carbohydrates must be >= 0'),
  fiber: z.number().min(0).default(0),
  sugar: z.number().min(0).nullable().optional(),
  sodium: z.number().min(0).nullable().optional(),
  servingSize: z.number().positive().nullable().optional(),
  servingUnit: z.string().trim().max(20).nullable().optional(),
  micronutrients: z
    .array(z.object({ key: z.string().min(1), amount: z.number(), unit: z.string().min(1) }))
    .optional(),
  aliases: z.array(z.string().min(1)).optional(),
});

export type CreateFoodBody = z.infer<typeof createFoodSchema>;

export const searchQuerySchema = z.object({
  q: z.string().trim().min(1).optional(),
  barcode: z.string().trim().min(1).optional(),
  category: z.string().trim().min(1).optional(),
  source: z.enum(['RAZVIT', 'USDA', 'OFF']).optional(),
  page: z.coerce.number().int().min(1).default(1),
  perPage: z.coerce.number().int().min(1).max(100).default(20),
  sort: z.string().default('name'),
});

export type SearchQuery = z.infer<typeof searchQuerySchema>;

// Реальные штрихкоды товаров (EAN-8/UPC-A/EAN-13/GTIN-14) — только цифры,
// 6-14 знаков. Отсекает мусор (буквы, QR-контент и т.п.) ещё до похода
// в базу/внешние API.
export const barcodeParamSchema = z.object({
  barcode: z
    .string()
    .trim()
    .regex(/^\d{6,14}$/, 'barcode must be 6-14 digits'),
});

export const idParamSchema = z.object({
  id: z.string().uuid('id must be a valid UUID'),
});

export const importQuerySchema = z.object({
  key: z.string().min(1, 'key is required'),
  page: z.coerce.number().int().min(1).default(1),
});
export type ImportQuery = z.infer<typeof importQuerySchema>;
