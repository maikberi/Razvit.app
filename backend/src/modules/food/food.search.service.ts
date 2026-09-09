import { OpenFoodFactsClient } from '../../integrations/openFoodFactsClient';
import { UsdaClient } from '../../integrations/usdaClient';
import { FoodRow, PagedResult, SearchParams } from './food.model';
import { normalizeName } from './food.normalize';
import { FoodService } from './food.service';

const MIN_LOCAL_RESULTS_BEFORE_EXTERNAL_FETCH = 5;
// Товар/блюдо считается "простым" (не составным рецептом из многих
// ингредиентов), если в его названии не больше этого числа слов.
const SIMPLE_NAME_MAX_WORDS = 2;

/**
 * Оркестрирует поиск: сперва своя база (RAZVIT + всё, что уже
 * импортировано ранее), и только если результатов мало — подключает
 * внешние источники (USDA — для стандартных продуктов, Open Food Facts —
 * для брендированных/штрихкодов), импортирует найденное с дедупликацией
 * и возвращает объединённый результат. Так каждый повторный поиск того
 * же запроса становится быстрее и не бьёт по внешним API без нужды.
 */
export class FoodSearchService {
  constructor(
    private readonly foodService: FoodService,
    private readonly usda: UsdaClient = new UsdaClient(),
    private readonly off: OpenFoodFactsClient = new OpenFoodFactsClient(),
  ) {}

  async search(params: SearchParams): Promise<PagedResult<FoodRow>> {
    const local = await this.foodService.listLocal(params);

    const shouldFetchExternal =
      Boolean(params.query) &&
      params.page === 1 &&
      (local.total < MIN_LOCAL_RESULTS_BEFORE_EXTERNAL_FETCH || !this.hasStrongLocalMatch(local.items, params.query!));
    if (!shouldFetchExternal) return local;

    const [usdaResults, offResults] = await Promise.all([
      this.usda.search(params.query!, params.perPage),
      this.off.search(params.query!, params.perPage),
    ]);

    for (const candidate of [...usdaResults, ...offResults]) {
      await this.foodService.findOrCreateFromExternal(candidate);
    }

    if (usdaResults.length === 0 && offResults.length === 0) return local;
    return this.foodService.listLocal(params);
  }

  /**
   * Есть ли среди локальных результатов "хорошее" совпадение — простой
   * товар, чьё название точно равно запросу или начинается с него как
   * отдельное слово (а не запрос-подстрока внутри составного блюда вроде
   * "Данонино ягода-банан" на запрос "банан"). Если такого нет, локальная
   * база не даёт того, что реально ищет пользователь, — стоит дополнительно
   * спросить внешние источники, даже если "мусорных" совпадений уже много.
   */
  private hasStrongLocalMatch(items: FoodRow[], query: string): boolean {
    const q = normalizeName(query);
    if (!q) return true;
    return items.some((food) => {
      const name = food.normalized_name;
      if (name === q) return true;
      // Запрос — первое слово названия (сам товар, а не блюдо, где это
      // слово — вкус/ингредиент в конце, вроде "Хлопья банан").
      const words = name.split(' ').filter(Boolean);
      return words.length <= SIMPLE_NAME_MAX_WORDS && name.startsWith(`${q} `);
    });
  }

  async lookupBarcode(barcode: string): Promise<FoodRow | null> {
    const existing = await this.foodService.listLocal({
      barcode,
      page: 1,
      perPage: 1,
      sort: 'name',
    });
    if (existing.items[0]) return existing.items[0];

    const fromOff = await this.off.lookupBarcode(barcode);
    if (!fromOff) return null;

    const { food } = await this.foodService.findOrCreateFromExternal(fromOff);
    return food;
  }
}
