import { NutrientProfile } from '../nutrition/nutrition.model';

/** Один распознанный на фото продукт, уже сопоставленный (или нет) с Food Database. */
export interface RecognizedFoodItem {
  aiName: string;
  estimatedGrams: number;
  confidence: number;
  possibleAlternatives: string[];
  uncertainty: string | null;
  /** null, если в базе не нашлось разумного совпадения — тогда nutrition тоже null,
   * пользователю нужно выбрать продукт вручную (см. критическое правило: AI не
   * источник истины для КБЖУ, только Food Database + Nutrition Engine). */
  matchedFoodId: string | null;
  matchedFoodName: string | null;
  matchedFoodImageUrl: string | null;
  matchedFoodEmoji: string | null;
  matchedBasisUnit: 'g' | 'ml' | null;
  nutrition: NutrientProfile | null;
}

export interface FoodRecognitionResult {
  items: RecognizedFoodItem[];
  notes: string | null;
}
