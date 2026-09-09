export type FoodSource = 'RAZVIT' | 'USDA' | 'OFF';
export type BasisUnit = 'g' | 'ml';

/** Строка таблицы foods как она лежит в БД. */
export interface FoodRow {
  id: string;
  name: string;
  normalized_name: string;
  brand: string | null;
  barcode: string | null;
  category: string | null;
  source: FoodSource;
  source_id: string | null;
  basis_unit: BasisUnit;
  calories: string; // numeric приходит из pg как строка
  protein: string;
  fat: string;
  carbohydrates: string;
  fiber: string;
  sugar: string | null;
  sodium: string | null;
  serving_size: string | null;
  serving_unit: string | null;
  image_url: string | null;
  verified: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface MicronutrientRow {
  id: number;
  food_id: string;
  key: string;
  amount: string;
  unit: string;
}

export interface AliasRow {
  id: number;
  food_id: string;
  alias: string;
  normalized_alias: string;
}

/** Данные для создания продукта — то, что нужно репозиторию. */
export interface CreateFoodInput {
  name: string;
  brand?: string | null;
  barcode?: string | null;
  category?: string | null;
  source: FoodSource;
  sourceId?: string | null;
  basisUnit: BasisUnit;
  calories: number;
  protein: number;
  fat: number;
  carbohydrates: number;
  fiber?: number;
  sugar?: number | null;
  sodium?: number | null;
  servingSize?: number | null;
  servingUnit?: string | null;
  imageUrl?: string | null;
  verified?: boolean;
  micronutrients?: { key: string; amount: number; unit: string }[];
  aliases?: string[];
}

export interface SearchParams {
  query?: string;
  barcode?: string;
  category?: string;
  source?: FoodSource;
  page: number;
  perPage: number;
  sort: string; // "name" | "-name" | "-created_at" ...
}

export interface PagedResult<T> {
  items: T[];
  page: number;
  perPage: number;
  total: number;
  totalPages: number;
}
