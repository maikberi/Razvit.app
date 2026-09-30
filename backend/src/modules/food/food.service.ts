import { FoodRepository } from './food.repository';
import { CreateFoodInput, FoodRow, PagedResult, SearchParams } from './food.model';

export class DuplicateFoodError extends Error {
  constructor(public readonly existing: FoodRow) {
    super('A food with this barcode already exists');
    this.name = 'DuplicateFoodError';
  }
}

export class FoodNotFoundError extends Error {
  constructor() {
    super('Food not found');
    this.name = 'FoodNotFoundError';
  }
}

/**
 * Бизнес-логика продуктов: создание своими руками (source=RAZVIT) идёт через
 * жёсткую проверку дублей по штрихкоду (409, а не тихая перезапись).
 * Импорт из внешних источников (USDA/OFF) — через findOrCreateFromExternal,
 * у которого более мягкая, многоуровневая дедупликация (см. её комментарий).
 */
export class FoodService {
  constructor(private readonly repo: FoodRepository) {}

  async getById(id: string): Promise<FoodRow> {
    const food = await this.repo.findById(id);
    if (!food) throw new FoodNotFoundError();
    return food;
  }

  async createOwn(input: CreateFoodInput): Promise<FoodRow> {
    if (input.barcode) {
      const existing = await this.repo.findByBarcode(input.barcode);
      if (existing) throw new DuplicateFoodError(existing);
    }
    return this.repo.create(input);
  }

  /**
   * Импорт продукта из внешнего источника (USDA/Open Food Facts) с защитой
   * от дублей. Порядок проверок — от самого надёжного идентификатора
   * к самому мягкому:
   *   1) штрихкод — если совпал, это точно тот же физический товар,
   *      неважно, из какого источника он был получен раньше;
   *   2) (source, source_id) — повторный импорт из ТОГО ЖЕ источника;
   *   3) fuzzy-совпадение по названию+бренду — ловит случай, когда один
   *      и тот же товар без штрихкода (например, стандартный продукт)
   *      приходит из USDA и из Open Food Facts под чуть разными id.
   * Если совпадений нет — создаём новую запись.
   */
  async findOrCreateFromExternal(input: CreateFoodInput): Promise<{ food: FoodRow; created: boolean }> {
    if (input.barcode) {
      const byBarcode = await this.repo.findByBarcode(input.barcode);
      if (byBarcode) return { food: byBarcode, created: false };
    }
    if (input.sourceId) {
      const bySource = await this.repo.findBySource(input.source, input.sourceId);
      if (bySource) return { food: bySource, created: false };
    }
    const similar = await this.repo.findSimilar(input.name, input.brand ?? null);
    if (similar) return { food: similar, created: false };

    const food = await this.repo.create(input);
    return { food, created: true };
  }

  async getMicronutrients(foodId: string) {
    return this.repo.getMicronutrients(foodId);
  }

  async getAliases(foodId: string) {
    return this.repo.getAliases(foodId);
  }

  async listLocal(params: SearchParams): Promise<PagedResult<FoodRow>> {
    return this.repo.search(params);
  }

  async getRecent(userId: string, limit = 12): Promise<FoodRow[]> {
    return this.repo.findRecent(userId, limit);
  }
}
