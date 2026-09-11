/** Один микронутриент: количество + единица (мг/мкг/МЕ и т.д.). */
export interface MicronutrientValue {
  amount: number;
  unit: string;
}

export type MicronutrientMap = Record<string, MicronutrientValue>;

/**
 * Нутриенты продукта на 100 г/100 мл — источник для расчёта (то, что
 * хранится в `foods`/`food_micronutrients`). sugar/sodium — nullable,
 * потому что не для всех продуктов они известны.
 */
export interface NutrientSource {
  calories: number;
  protein: number;
  fat: number;
  carbohydrates: number;
  fiber: number;
  sugar: number | null;
  sodium: number | null;
  micronutrients?: MicronutrientMap;
}

/** Результат расчёта — уже округлённые, готовые к показу значения. */
export interface NutrientProfile {
  calories: number;
  protein: number;
  fat: number;
  carbohydrates: number;
  fiber: number;
  sugar: number | null;
  sodium: number | null;
  micronutrients: MicronutrientMap;
}

/** Один продукт в конкретном количестве — единица ввода для Meal/Recipe/Day. */
export interface FoodAmount {
  food: NutrientSource;
  grams: number;
}
