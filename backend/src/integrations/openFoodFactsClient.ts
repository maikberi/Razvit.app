import { env } from '../config/env';
import { CreateFoodInput } from '../modules/food/food.model';

/**
 * Клиент Open Food Facts — перенесён сюда с Flutter-клиента
 * (lib/data/services/open_food_facts_service.dart), чтобы внешние
 * запросы шли только с backend, а не напрямую с телефона пользователя.
 * Используется для брендированных продуктов и поиска по штрихкоду.
 */
export class OpenFoodFactsClient {
  constructor(private readonly baseUrl: string = env.openFoodFactsBaseUrl) {}

  async search(query: string, limit = 15): Promise<CreateFoodInput[]> {
    if (query.trim().length < 3) return [];
    try {
      const url = new URL(`${this.baseUrl}/cgi/search.pl`);
      url.searchParams.set('search_terms', query);
      url.searchParams.set('search_simple', '1');
      url.searchParams.set('action', 'process');
      url.searchParams.set('json', '1');
      url.searchParams.set('page_size', String(limit));
      url.searchParams.set(
        'fields',
        'code,product_name,product_name_ru,brands,nutriments,serving_size,serving_quantity,image_front_small_url',
      );

      const res = await fetchWithTimeout(url.toString());
      if (!res.ok) return [];
      const data = (await res.json()) as { products?: unknown[] };
      return (data.products ?? []).map(toFoodInput).filter((f): f is CreateFoodInput => f !== null);
    } catch {
      return [];
    }
  }

  /**
   * Продукты, у которых в OFF указана страна продажи (для наполнения
   * каталога заранее — российских брендов почти нет ни в USDA (это
   * американская база), ни в результатах живого текстового поиска по OFF
   * (у него слабый fuzzy-match по кириллице), хотя в самой базе OFF они
   * есть — просто через полнотекстовый поиск не находятся). Постранично,
   * без ограничения по числу совпадений с запросом — используется
   * FoodImportService для разовой пакетной загрузки.
   */
  async searchByCountry(country: string, page: number, pageSize: number): Promise<CreateFoodInput[]> {
    try {
      const url = new URL(`${this.baseUrl}/cgi/search.pl`);
      url.searchParams.set('action', 'process');
      url.searchParams.set('json', '1');
      url.searchParams.set('page', String(page));
      url.searchParams.set('page_size', String(pageSize));
      url.searchParams.set('tagtype_0', 'countries');
      url.searchParams.set('tag_contains_0', 'contains');
      url.searchParams.set('tag_0', country);
      url.searchParams.set(
        'fields',
        'code,product_name,product_name_ru,brands,nutriments,serving_size,serving_quantity,image_front_small_url',
      );

      const res = await fetchWithTimeout(url.toString(), 15000);
      if (!res.ok) return [];
      const data = (await res.json()) as { products?: unknown[] };
      return (data.products ?? []).map(toFoodInput).filter((f): f is CreateFoodInput => f !== null);
    } catch {
      return [];
    }
  }

  async lookupBarcode(barcode: string): Promise<CreateFoodInput | null> {
    const code = barcode.trim();
    if (!code) return null;
    try {
      const res = await fetchWithTimeout(`${this.baseUrl}/api/v0/product/${encodeURIComponent(code)}.json`);
      if (!res.ok) return null;
      const data = (await res.json()) as { status?: number; product?: unknown };
      if (data.status !== 1 || !data.product) return null;
      return toFoodInput(data.product);
    } catch {
      return null;
    }
  }
}

async function fetchWithTimeout(url: string, timeoutMs = 6000): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { signal: controller.signal, headers: { 'User-Agent': 'RAZVIT/1.0 (backend)' } });
  } finally {
    clearTimeout(timeout);
  }
}

function toFoodInput(raw: unknown): CreateFoodInput | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const r = raw as Record<string, unknown>;

  const nameRu = typeof r.product_name_ru === 'string' ? r.product_name_ru.trim() : '';
  const nameEn = typeof r.product_name === 'string' ? r.product_name.trim() : '';
  const name = nameRu || nameEn;
  if (!name) return null;

  const nutriments = r.nutriments as Record<string, unknown> | undefined;
  if (!nutriments) return null;
  const calories = asNumber(nutriments['energy-kcal_100g']);
  if (calories == null) return null;

  const code = typeof r.code === 'string' ? r.code : undefined;

  // Предпочитаем маленькую версию (быстрее грузится в списке/детали, чем
  // полноразмерная) — OFF отдаёт её отдельным полем; для запроса по
  // штрихкоду (без ограничения fields) может не быть image_front_small_url,
  // тогда берём обычный image_url.
  const imageUrl =
    (typeof r.image_front_small_url === 'string' && r.image_front_small_url) ||
    (typeof r.image_url === 'string' && r.image_url) ||
    null;

  return {
    name,
    brand: typeof r.brands === 'string' && r.brands.trim() ? r.brands.split(',')[0].trim() : null,
    barcode: code ?? null,
    category: null,
    source: 'OFF',
    sourceId: code ?? null,
    basisUnit: 'g',
    imageUrl,
    calories,
    protein: asNumber(nutriments['proteins_100g']) ?? 0,
    fat: asNumber(nutriments['fat_100g']) ?? 0,
    carbohydrates: asNumber(nutriments['carbohydrates_100g']) ?? 0,
    fiber: asNumber(nutriments['fiber_100g']) ?? 0,
    sugar: asNumber(nutriments['sugars_100g']),
    sodium: asNumber(nutriments['sodium_100g']) != null ? Number(asNumber(nutriments['sodium_100g'])) * 1000 : null,
    servingSize: asNumber(r.serving_quantity),
    servingUnit: asNumber(r.serving_quantity) != null ? 'g' : null,
    verified: false,
  };
}

function asNumber(v: unknown): number | null {
  if (v == null) return null;
  if (typeof v === 'number') return v;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}
