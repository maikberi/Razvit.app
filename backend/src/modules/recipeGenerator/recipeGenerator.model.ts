import { NutrientProfile } from '../nutrition/nutrition.model';
import { FoodMatchTier } from '../food/food.matching';
import { RecipeUnit } from '../recipe/recipe.model';

/** Ограничения на КБЖУ ОДНОЙ ПОРЦИИ, которые AI извлёк из свободного текста запроса пользователя. */
export interface RecipeGenerationConstraints {
  minCalories?: number;
  maxCalories?: number;
  minProtein?: number;
  maxProtein?: number;
  minFat?: number;
  maxFat?: number;
  minCarbohydrates?: number;
  maxCarbohydrates?: number;
}

/** Один ингредиент придуманного AI рецепта, уже сопоставленный (или нет) с Food Database. */
export interface GeneratedIngredient {
  aiName: string;
  quantity: number;
  unit: RecipeUnit;
  grams: number;
  /** null, если в базе не нашлось совпадения — тогда этот ингредиент не входит
   * в расчёт КБЖУ, а рецепт нельзя сохранить/добавить в дневник, пока
   * пользователь не выберет продукт вручную (тот же принцип, что и в AI
   * Food Recognition — AI не источник истины, только Food Database). */
  matchedFoodId: string | null;
  matchedFoodName: string | null;
  matchedFoodImageUrl: string | null;
  matchedFoodEmoji: string | null;
  matchTier: FoodMatchTier | null;
  matchScore: number | null;
}

export interface GeneratedRecipe {
  name: string;
  description: string | null;
  servings: number;
  cookingTimeMinutes: number | null;
  instructions: string;
  ingredients: GeneratedIngredient[];
  nutrition: { total: NutrientProfile; perServing: NutrientProfile };
  /** Ограничения, которые AI распознал в запросе — null, если пользователь не называл конкретных чисел. */
  constraints: RecipeGenerationConstraints | null;
  /** false — даже после попытки пересчитать порцию и повторной генерации не удалось точно уложиться в заданные рамки. */
  constraintsSatisfied: boolean;
  /** true — хотя бы один ингредиент не нашёлся в базе, нужно выбрать вручную перед сохранением. */
  hasUnresolvedIngredients: boolean;
  /** Человеко-читаемое объяснение того, что backend сделал с рецептом, чтобы попасть в ограничения (если делал). */
  adjustmentNote: string | null;
}
