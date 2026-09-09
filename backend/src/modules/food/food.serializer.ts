import { FoodRow, MicronutrientRow, PagedResult } from './food.model';

/**
 * Форма JSON-ответа намеренно повторяет поля существующей Flutter-модели
 * FoodItem (caloriesPer100g, proteinPer100g, fatPer100g, carbsPer100g,
 * fiberPer100g, defaultGrams) — чтобы клиенту не нужен был отдельный
 * маппер, только fromJson с новыми опциональными полями.
 */
export interface FoodDTO {
  id: string;
  name: string;
  brand: string | null;
  barcode: string | null;
  category: string | null;
  source: string;
  verified: boolean;
  basisUnit: 'g' | 'ml';
  caloriesPer100g: number;
  proteinPer100g: number;
  fatPer100g: number;
  carbsPer100g: number;
  fiberPer100g: number;
  sugarPer100g: number | null;
  sodiumPer100g: number | null;
  defaultGrams: number;
  servingUnit: string | null;
  imageUrl: string | null;
  micronutrients: Record<string, { amount: number; unit: string }>;
  createdAt: string;
  updatedAt: string;
}

export function serializeFood(food: FoodRow, micronutrients: MicronutrientRow[] = []): FoodDTO {
  return {
    id: food.id,
    name: food.name,
    brand: food.brand,
    barcode: food.barcode,
    category: food.category,
    source: food.source,
    verified: food.verified,
    basisUnit: food.basis_unit,
    caloriesPer100g: Number(food.calories),
    proteinPer100g: Number(food.protein),
    fatPer100g: Number(food.fat),
    carbsPer100g: Number(food.carbohydrates),
    fiberPer100g: Number(food.fiber),
    sugarPer100g: food.sugar != null ? Number(food.sugar) : null,
    sodiumPer100g: food.sodium != null ? Number(food.sodium) : null,
    defaultGrams: food.serving_size != null ? Number(food.serving_size) : 100,
    servingUnit: food.serving_unit,
    imageUrl: food.image_url,
    micronutrients: micronutrients.reduce<Record<string, { amount: number; unit: string }>>((acc, m) => {
      acc[m.key] = { amount: Number(m.amount), unit: m.unit };
      return acc;
    }, {}),
    createdAt: food.created_at.toISOString(),
    updatedAt: food.updated_at.toISOString(),
  };
}

export function serializePage(page: PagedResult<FoodRow>) {
  return {
    data: page.items.map((f) => serializeFood(f)),
    meta: {
      page: page.page,
      perPage: page.perPage,
      total: page.total,
      totalPages: page.totalPages,
    },
  };
}
