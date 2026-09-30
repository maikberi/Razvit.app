import { FoodRepository } from './food.repository';
import { FoodRow } from './food.model';
import { normalizeName } from './food.normalize';
import { logEvent } from '../../utils/logger';

export type FoodMatchTier = 'exact' | 'alias' | 'fuzzy' | 'category';

export interface FoodMatchResult {
  food: FoodRow;
  tier: FoodMatchTier;
  /** 0..1 — насколько уверенно САМО сопоставление (не уверенность AI в том, что на фото/в рецепте вообще этот продукт). */
  score: number;
}

const CATEGORY_TIER_SCORE = 0.2;

/**
 * Сопоставляет "сырое" название продукта (от AI Food Recognition или AI
 * Recipe Generator) с реальной записью в Food Database — по возрастанию
 * мягкости: точное название -> алиас -> похожее по написанию -> похоже на
 * категорию. Останавливается на первой ступени, которая что-то нашла —
 * более строгая ступень всегда предпочтительнее более мягкой, даже если
 * "похожесть" у неё формально не самая высокая.
 *
 * Логирует каждый вызов (см. utils/logger.ts) — без изображения, без
 * userId и любых других персональных данных, только сам пайплайн
 * сопоставления (что искали, что нашли, на какой ступени).
 */
export class FoodMatchingService {
  constructor(private readonly foods: FoodRepository) {}

  async match(rawName: string): Promise<FoodMatchResult | null> {
    const normalized = normalizeName(rawName);
    if (!normalized) return null;

    const exact = await this.foods.findByExactName(normalized);
    if (exact) return this.logAndReturn(rawName, { food: exact, tier: 'exact', score: 1 });

    const alias = await this.foods.findByAlias(normalized);
    if (alias) return this.logAndReturn(rawName, { food: alias, tier: 'alias', score: 0.95 });

    const fuzzy = await this.foods.findFuzzyMatch(normalized);
    if (fuzzy) return this.logAndReturn(rawName, { food: fuzzy.food, tier: 'fuzzy', score: fuzzy.similarity });

    const category = await this.foods.findByCategoryMatch(normalized);
    if (category) return this.logAndReturn(rawName, { food: category, tier: 'category', score: CATEGORY_TIER_SCORE });

    logEvent('food_match', { query: rawName, matched: false });
    return null;
  }

  private logAndReturn(rawName: string, result: FoodMatchResult): FoodMatchResult {
    logEvent('food_match', {
      query: rawName,
      matched: true,
      tier: result.tier,
      score: Math.round(result.score * 100) / 100,
      matchedFoodId: result.food.id,
      matchedFoodName: result.food.name,
    });
    return result;
  }
}
