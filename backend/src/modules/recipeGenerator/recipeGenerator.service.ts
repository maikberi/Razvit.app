import { FoodRow } from '../food/food.model';
import { FoodMatchingService, FoodMatchTier } from '../food/food.matching';
import { convertToGrams, FoodQuantityUnitError } from '../food/food.units';
import { NutritionCalculationService, roundTo } from '../nutrition/nutrition.calculation.service';
import { FoodAmount, NutrientProfile, NutrientSource } from '../nutrition/nutrition.model';
import { RecipeUnit } from '../recipe/recipe.model';
import { RecipeDraft, RecipeDraftIngredient, RecipeGeneratorClient } from '../../integrations/recipeGeneratorClient';
import { logEvent } from '../../utils/logger';
import { GeneratedIngredient, GeneratedRecipe, RecipeGenerationConstraints } from './recipeGenerator.model';

// Запас (доля), на который целимся ВНУТРЬ границы, а не точно на неё — иначе
// округление NutrientProfile (см. ROUNDING) может вытолкнуть результат
// обратно за пределы constraint после округления до целых/десятых.
const SCALE_SAFETY_MARGIN = 0.02;
// За эти пределы порцию не масштабируем ни в одну сторону — до такой степени
// "уменьшить/увеличить ингредиенты" уже не значит "пересчитать рецепт",
// а значит "это другой рецепт"; в этом случае считаем задачу невыполнимой
// подбором коэффициента и уходим на повторную AI-генерацию.
const MIN_SCALE_FACTOR = 0.3;
const MAX_SCALE_FACTOR = 3;

interface ResolvedIngredient {
  aiName: string;
  quantity: number;
  unit: RecipeUnit;
  grams: number;
  food: FoodRow | null;
  matchTier: FoodMatchTier | null;
  matchScore: number | null;
}

interface ScaleResult {
  feasible: boolean;
  factor: number;
}

function toNutrientSource(food: FoodRow): NutrientSource {
  return {
    calories: Number(food.calories),
    protein: Number(food.protein),
    fat: Number(food.fat),
    carbohydrates: Number(food.carbohydrates),
    fiber: Number(food.fiber),
    sugar: food.sugar != null ? Number(food.sugar) : null,
    sodium: food.sodium != null ? Number(food.sodium) : null,
  };
}

function violatesConstraints(perServing: NutrientProfile, c: RecipeGenerationConstraints): boolean {
  if (c.minCalories != null && perServing.calories < c.minCalories) return true;
  if (c.maxCalories != null && perServing.calories > c.maxCalories) return true;
  if (c.minProtein != null && perServing.protein < c.minProtein) return true;
  if (c.maxProtein != null && perServing.protein > c.maxProtein) return true;
  if (c.minFat != null && perServing.fat < c.minFat) return true;
  if (c.maxFat != null && perServing.fat > c.maxFat) return true;
  if (c.minCarbohydrates != null && perServing.carbohydrates < c.minCarbohydrates) return true;
  if (c.maxCarbohydrates != null && perServing.carbohydrates > c.maxCarbohydrates) return true;
  return false;
}

/**
 * Ищет коэффициент масштабирования всех ингредиентов сразу (линейно —
 * каждый нутриент масштабируется пропорционально граммовке), который
 * удовлетворяет ВСЕМ заданным ограничениям одновременно. Пересечение
 * допустимых интервалов по каждому нутриенту может оказаться пустым —
 * тогда одним числом одновременно все ограничения не удовлетворить
 * (например min по белку и max по калориям физически противоречат друг
 * другу при данном наборе ингредиентов) и feasible=false.
 */
function computeScaleFactor(perServing: NutrientProfile, constraints: RecipeGenerationConstraints): ScaleResult {
  let lower = MIN_SCALE_FACTOR;
  let upper = MAX_SCALE_FACTOR;

  const apply = (actual: number, min?: number, max?: number) => {
    if (min != null) {
      lower = actual > 0 ? Math.max(lower, (min / actual) * (1 + SCALE_SAFETY_MARGIN)) : Infinity;
    }
    if (max != null && actual > 0) {
      upper = Math.min(upper, (max / actual) * (1 - SCALE_SAFETY_MARGIN));
    }
  };

  apply(perServing.calories, constraints.minCalories, constraints.maxCalories);
  apply(perServing.protein, constraints.minProtein, constraints.maxProtein);
  apply(perServing.fat, constraints.minFat, constraints.maxFat);
  apply(perServing.carbohydrates, constraints.minCarbohydrates, constraints.maxCarbohydrates);

  if (lower > upper) return { feasible: false, factor: 1 };
  // Берём границу, которая реально требовалась (ближе к исходному рецепту),
  // а не середину интервала — меняем ингредиенты минимально необходимо.
  return { feasible: true, factor: lower > 1 ? lower : upper };
}

function describeScale(factor: number): string {
  if (factor < 1) return `Уменьшили порцию (${Math.round((1 - factor) * 100)}%), чтобы уложиться в заданные ограничения по КБЖУ`;
  return `Увеличили порцию (${Math.round((factor - 1) * 100)}%), чтобы достичь заданного минимума по КБЖУ`;
}

/**
 * AI Recipe Generator — оркестрирует весь путь текстовый запрос -> рецепт:
 * User Request -> AI (название, ингредиенты, количества, инструкция,
 * распознанные ограничения по КБЖУ) -> сопоставление ингредиентов с Food
 * Database -> расчёт реального КБЖУ через Nutrition Engine -> валидация
 * против ограничений -> при несоответствии: пропорциональный пересчёт
 * порции, а если и так не уложиться — ОДНА повторная AI-генерация с
 * обратной связью о реальных цифрах. AI никогда не является источником
 * истины для КБЖУ — только Food Database + Nutrition Engine.
 */
export class RecipeGeneratorService {
  constructor(
    private readonly client: RecipeGeneratorClient,
    private readonly matching: FoodMatchingService,
    private readonly engine: NutritionCalculationService,
  ) {}

  async generate(prompt: string): Promise<GeneratedRecipe> {
    const draft = await this.client.generate(prompt);
    const constraints = this.normalizeConstraints(draft.constraints);
    let resolved = await this.resolveIngredients(draft.ingredients);
    let nutrition = this.engine.forRecipe(this.toFoodAmounts(resolved), draft.servings);

    let adjustmentNote: string | null = null;
    let retried = false;
    let finalDraft: RecipeDraft = draft;

    if (constraints && violatesConstraints(nutrition.perServing, constraints)) {
      const scale = computeScaleFactor(nutrition.perServing, constraints);

      if (scale.feasible) {
        resolved = this.applyScale(resolved, scale.factor);
        nutrition = this.engine.forRecipe(this.toFoodAmounts(resolved), draft.servings);
        adjustmentNote = describeScale(scale.factor);
      } else {
        retried = true;
        const feedback = this.buildFeedback(nutrition.perServing, constraints);
        finalDraft = await this.client.generate(prompt, feedback);
        resolved = await this.resolveIngredients(finalDraft.ingredients);
        nutrition = this.engine.forRecipe(this.toFoodAmounts(resolved), finalDraft.servings);

        if (violatesConstraints(nutrition.perServing, constraints)) {
          const retryScale = computeScaleFactor(nutrition.perServing, constraints);
          if (retryScale.feasible) {
            resolved = this.applyScale(resolved, retryScale.factor);
            nutrition = this.engine.forRecipe(this.toFoodAmounts(resolved), finalDraft.servings);
            adjustmentNote = `Повторили генерацию и ${describeScale(retryScale.factor).toLowerCase()}`;
          } else {
            adjustmentNote = 'Не удалось точно попасть в заданные ограничения по КБЖУ — это ближайший реалистичный вариант';
          }
        }
      }
    }

    const constraintsSatisfied = !constraints || !violatesConstraints(nutrition.perServing, constraints);
    const hasUnresolvedIngredients = resolved.some((r) => r.food === null);

    logEvent('recipe_generation', {
      promptLength: prompt.length,
      ingredientCount: resolved.length,
      unresolvedCount: resolved.filter((r) => r.food === null).length,
      hasConstraints: constraints !== null,
      constraintsSatisfied,
      retried,
    });

    return this.assemble(finalDraft, resolved, nutrition, constraints, constraintsSatisfied, hasUnresolvedIngredients, adjustmentNote);
  }

  private normalizeConstraints(raw: RecipeDraft['constraints']): RecipeGenerationConstraints | null {
    if (!raw || Object.keys(raw).length === 0) return null;
    return raw;
  }

  private async resolveIngredients(ingredients: RecipeDraftIngredient[]): Promise<ResolvedIngredient[]> {
    return Promise.all(
      ingredients.map(async (ing): Promise<ResolvedIngredient> => {
        const result = await this.matching.match(ing.name);
        if (!result) {
          return { aiName: ing.name, quantity: ing.quantity, unit: ing.unit, grams: 0, food: null, matchTier: null, matchScore: null };
        }
        try {
          const grams = convertToGrams(result.food, ing.quantity, ing.unit);
          return { aiName: ing.name, quantity: ing.quantity, unit: ing.unit, grams, food: result.food, matchTier: result.tier, matchScore: result.score };
        } catch (err) {
          if (err instanceof FoodQuantityUnitError) {
            // Нашли продукт, но им нельзя посчитать 'pcs' — просим пользователя разобраться вручную,
            // как с несопоставленным ингредиентом (не блокируем всю генерацию рецепта).
            return { aiName: ing.name, quantity: ing.quantity, unit: ing.unit, grams: 0, food: null, matchTier: null, matchScore: null };
          }
          throw err;
        }
      }),
    );
  }

  private toFoodAmounts(resolved: ResolvedIngredient[]): FoodAmount[] {
    return resolved.filter((r) => r.food !== null).map((r) => ({ food: toNutrientSource(r.food as FoodRow), grams: r.grams }));
  }

  private applyScale(resolved: ResolvedIngredient[], factor: number): ResolvedIngredient[] {
    return resolved.map((r) => (r.food ? { ...r, quantity: roundTo(r.quantity * factor, 2), grams: r.grams * factor } : r));
  }

  private buildFeedback(perServing: NutrientProfile, c: RecipeGenerationConstraints): string {
    const need: string[] = [];
    if (c.maxCalories != null) need.push(`не больше ${c.maxCalories} ккал`);
    if (c.minCalories != null) need.push(`не меньше ${c.minCalories} ккал`);
    if (c.maxProtein != null) need.push(`не больше ${c.maxProtein} г белка`);
    if (c.minProtein != null) need.push(`не меньше ${c.minProtein} г белка`);
    if (c.maxFat != null) need.push(`не больше ${c.maxFat} г жиров`);
    if (c.minFat != null) need.push(`не меньше ${c.minFat} г жиров`);
    if (c.maxCarbohydrates != null) need.push(`не больше ${c.maxCarbohydrates} г углеводов`);
    if (c.minCarbohydrates != null) need.push(`не меньше ${c.minCarbohydrates} г углеводов`);

    return (
      `Предыдущий вариант дал на порцию: ${perServing.calories} ккал, ${perServing.protein} г белка, ` +
      `${perServing.fat} г жиров, ${perServing.carbohydrates} г углеводов. Нужно на порцию: ${need.join(', ')}. ` +
      `Пересмотри ингредиенты и их количества (замени или измени граммовку), чтобы попасть точнее в эти рамки, ` +
      `сохранив тот же стиль блюда.`
    );
  }

  private assemble(
    draft: RecipeDraft,
    resolved: ResolvedIngredient[],
    nutrition: { total: NutrientProfile; perServing: NutrientProfile },
    constraints: RecipeGenerationConstraints | null,
    constraintsSatisfied: boolean,
    hasUnresolvedIngredients: boolean,
    adjustmentNote: string | null,
  ): GeneratedRecipe {
    const ingredients: GeneratedIngredient[] = resolved.map((r) => ({
      aiName: r.aiName,
      quantity: r.quantity,
      unit: r.unit,
      grams: r.grams,
      matchedFoodId: r.food?.id ?? null,
      matchedFoodName: r.food?.name ?? null,
      matchedFoodImageUrl: r.food?.image_url ?? null,
      matchedFoodEmoji: r.food?.emoji ?? null,
      matchTier: r.matchTier,
      matchScore: r.matchScore,
    }));

    return {
      name: draft.name,
      description: draft.description ?? null,
      servings: draft.servings,
      cookingTimeMinutes: draft.cookingTimeMinutes ?? null,
      instructions: draft.instructions,
      ingredients,
      nutrition,
      constraints,
      constraintsSatisfied,
      hasUnresolvedIngredients,
      adjustmentNote,
    };
  }
}
