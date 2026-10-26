export const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snack'] as const;
export type MealType = (typeof MEAL_TYPES)[number];

export interface MealRow {
  id: string;
  user_id: string;
  type: MealType;
  date: string;
  time: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface MealItemRow {
  id: string;
  meal_id: string;
  food_id: string | null;
  custom_name: string | null;
  custom_nutrients: {
    calories: number;
    protein: number;
    fat: number;
    carbohydrates: number;
    fiber?: number;
    sugar?: number | null;
    sodium?: number | null;
  } | null;
  grams: string;
  created_at: Date;
}
