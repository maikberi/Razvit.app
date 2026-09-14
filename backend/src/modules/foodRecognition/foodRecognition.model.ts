import { NutrientProfile } from '../nutrition/nutrition.model';
import { FoodMatchTier } from '../food/food.matching';

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
  /** На какой ступени пайплайна (exact/alias/fuzzy/category) нашли совпадение; null — не нашли вообще. */
  matchTier: FoodMatchTier | null;
  /** Насколько уверенно само сопоставление (0..1) — не путать с confidence самого AI. */
  matchScore: number | null;
  /**
   * true — нельзя молча показать предполагаемый результат, пользователь должен
   * подтвердить или изменить (низкая уверенность AI, слабая ступень совпадения
   * или совпадения вообще не нашлось).
   */
  needsConfirmation: boolean;
  nutrition: NutrientProfile | null;
}

export interface FoodRecognitionResult {
  items: RecognizedFoodItem[];
  notes: string | null;
}
