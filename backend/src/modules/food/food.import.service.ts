import { OpenFoodFactsClient } from '../../integrations/openFoodFactsClient';
import { FoodService } from './food.service';

export interface ImportProgress {
  importedCount: number;
  skippedCount: number;
  lastPage: number;
  done: boolean;
}

const PAGE_SIZE = 100;
// Укладываемся с запасом в таймаут облачной функции (обычно 30 сек) —
// эндпоинт можно безопасно дёргать повторно, продолжая с lastPage + 1,
// пока done === false.
const TIME_BUDGET_MS = 20000;

/**
 * Разовое (или повторяемое) наполнение каталога продуктами, которые OFF
 * относит к России, но которые не всплывают через обычный текстовый
 * поиск (см. комментарий в OpenFoodFactsClient.searchByCountry). Не
 * трогает уже существующие записи — findOrCreateFromExternal сам
 * пропускает то, что уже есть (по штрихкоду/source+sourceId/похожести).
 */
export class FoodImportService {
  constructor(
    private readonly foodService: FoodService,
    private readonly off: OpenFoodFactsClient = new OpenFoodFactsClient(),
  ) {}

  async importRussianProducts(startPage: number): Promise<ImportProgress> {
    const startedAt = Date.now();
    let page = startPage;
    let importedCount = 0;
    let skippedCount = 0;

    while (Date.now() - startedAt < TIME_BUDGET_MS) {
      const candidates = await this.off.searchByCountry('Russia', page, PAGE_SIZE);
      if (candidates.length === 0) {
        return { importedCount, skippedCount, lastPage: page, done: true };
      }
      for (const candidate of candidates) {
        try {
          await this.foodService.findOrCreateFromExternal(candidate);
          importedCount++;
        } catch {
          skippedCount++;
        }
      }
      page++;
    }
    return { importedCount, skippedCount, lastPage: page - 1, done: false };
  }
}
