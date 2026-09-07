import { OpenFoodFactsClient } from '../../integrations/openFoodFactsClient';
import { UsdaClient } from '../../integrations/usdaClient';
import { FoodRow, PagedResult, SearchParams } from './food.model';
import { FoodService } from './food.service';

const MIN_LOCAL_RESULTS_BEFORE_EXTERNAL_FETCH = 5;

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

    const shouldFetchExternal = Boolean(params.query) && local.total < MIN_LOCAL_RESULTS_BEFORE_EXTERNAL_FETCH && params.page === 1;
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
