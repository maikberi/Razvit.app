export type RecipeUnit = 'g' | 'ml' | 'pcs';

/** Строка таблицы recipes как она лежит в БД. */
export interface RecipeRow {
  id: string;
  user_id: string;
  name: string;
  description: string | null;
  image_url: string | null;
  servings: string; // numeric приходит из pg как строка
  cooking_time_minutes: number | null;
  instructions: string;
  created_at: Date;
  updated_at: Date;
}

export interface RecipeIngredientRow {
  id: string;
  recipe_id: string;
  food_id: string;
  quantity: string;
  unit: RecipeUnit;
  position: number;
  created_at: Date;
}

export interface RecipeIngredientInput {
  foodId: string;
  quantity: number;
  unit: RecipeUnit;
}

/** Данные для создания/полной замены рецепта — то, что нужно репозиторию. */
export interface RecipeInput {
  name: string;
  description?: string | null;
  imageUrl?: string | null;
  servings: number;
  cookingTimeMinutes?: number | null;
  instructions: string;
  ingredients: RecipeIngredientInput[];
}

export interface RecipeSearchParams {
  userId: string;
  q?: string;
  mine?: boolean;
  favoriteOnly?: boolean;
  page: number;
  perPage: number;
}
