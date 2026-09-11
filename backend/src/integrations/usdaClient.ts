import { env } from '../config/env';
import { CreateFoodInput } from '../modules/food/food.model';

/**
 * Клиент USDA FoodData Central — источник для стандартных (небрендированных)
 * продуктов ("Rice, white, cooked" и т.п.). Без API-ключа просто отдаёт
 * пустой список — это не ошибка, поиск продолжает работать по RAZVIT/OFF.
 * Ключ берётся строго из переменной окружения USDA_API_KEY.
 */
const NUTRIENT_NUMBERS = {
  calories: '208',
  protein: '203',
  fat: '204',
  carbohydrates: '205',
  fiber: '291',
  sugar: '269',
  sodium: '307',
};

export class UsdaClient {
  constructor(
    private readonly apiKey: string = env.usdaApiKey,
    private readonly baseUrl = 'https://api.nal.usda.gov/fdc/v1',
  ) {}

  get enabled(): boolean {
    return this.apiKey.length > 0;
  }

  async search(query: string, limit = 15): Promise<CreateFoodInput[]> {
    if (!this.enabled || query.trim().length < 3) return [];
    try {
      const url = new URL(`${this.baseUrl}/foods/search`);
      url.searchParams.set('api_key', this.apiKey);
      url.searchParams.set('query', query);
      url.searchParams.set('pageSize', String(limit));
      url.searchParams.set('dataType', 'Foundation,SR Legacy');

      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 6000);
      const res = await fetch(url.toString(), { signal: controller.signal }).finally(() => clearTimeout(timeout));
      if (!res.ok) return [];
      const data = (await res.json()) as { foods?: unknown[] };
      return (data.foods ?? []).map(toFoodInput).filter((f): f is CreateFoodInput => f !== null);
    } catch {
      return [];
    }
  }
}

function toFoodInput(raw: unknown): CreateFoodInput | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const description = typeof r.description === 'string' ? r.description.trim() : '';
  if (!description) return null;

  const nutrients = (r.foodNutrients as Array<Record<string, unknown>> | undefined) ?? [];
  const byNumber = new Map<string, number>();
  for (const n of nutrients) {
    const number = String(n.nutrientNumber ?? '');
    const value = Number(n.value);
    if (number && Number.isFinite(value)) byNumber.set(number, value);
  }
  const calories = byNumber.get(NUTRIENT_NUMBERS.calories);
  if (calories == null) return null;

  return {
    name: description,
    brand: typeof r.brandOwner === 'string' && r.brandOwner.trim() ? r.brandOwner.trim() : null,
    barcode: typeof r.gtinUpc === 'string' ? r.gtinUpc : null,
    category: typeof r.foodCategory === 'string' ? r.foodCategory : null,
    source: 'USDA',
    sourceId: r.fdcId != null ? String(r.fdcId) : null,
    basisUnit: 'g',
    calories,
    protein: byNumber.get(NUTRIENT_NUMBERS.protein) ?? 0,
    fat: byNumber.get(NUTRIENT_NUMBERS.fat) ?? 0,
    carbohydrates: byNumber.get(NUTRIENT_NUMBERS.carbohydrates) ?? 0,
    fiber: byNumber.get(NUTRIENT_NUMBERS.fiber) ?? 0,
    sugar: byNumber.get(NUTRIENT_NUMBERS.sugar) ?? null,
    sodium: byNumber.get(NUTRIENT_NUMBERS.sodium) ?? null,
    servingSize: null,
    servingUnit: null,
    verified: true,
  };
}
