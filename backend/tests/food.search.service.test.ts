import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { FoodRepository } from '../src/modules/food/food.repository';
import { FoodSearchService } from '../src/modules/food/food.search.service';
import { FoodService } from '../src/modules/food/food.service';

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE foods RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

// Регрессия на баг: поиск "банан" находил только составные товары
// ("Данонино ягода-банан", "Венский завтрак банан"), где это слово —
// лишь один из ингредиентов, а не сам банан, и из-за этого ни разу не
// обращался к внешним источникам (Open Food Facts) за нормальным товаром.
describe('FoodSearchService — качество совпадений на простой запрос', () => {
  function buildService(offSearchResult: unknown[] = []) {
    const repo = new FoodRepository(pool);
    const service = new FoodService(repo);
    const usda = { search: jest.fn().mockResolvedValue([]) };
    const off = { search: jest.fn().mockResolvedValue(offSearchResult), lookupBarcode: jest.fn() };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const searchService = new FoodSearchService(service, usda as any, off as any);
    return { service, usda, off, searchService };
  }

  it('простой товар "Банан" ранжируется выше составных блюд с тем же словом', async () => {
    const { service, searchService } = buildService();
    const composite = ['Данонино ягода-банан', 'Венский завтрак банан', 'Хлопья банан', 'Смузи банан-клубника'];
    for (const name of composite) {
      await service.createOwn({ name, source: 'RAZVIT', basisUnit: 'g', calories: 100, protein: 3, fat: 2, carbohydrates: 15 });
    }
    await service.createOwn({ name: 'Банан', source: 'RAZVIT', basisUnit: 'g', calories: 96, protein: 1.5, fat: 0.2, carbohydrates: 21 });

    const res = await searchService.search({ query: 'банан', page: 1, perPage: 20, sort: 'name' });

    expect(res.items[0].name).toBe('Банан');
  });

  it('обращается к внешним источникам, даже если локальных совпадений уже много, но среди них нет простого товара', async () => {
    const { service, off, searchService } = buildService([
      {
        name: 'Банан',
        source: 'OFF' as const,
        sourceId: 'off-banana',
        basisUnit: 'g' as const,
        calories: 96,
        protein: 1.5,
        fat: 0.2,
        carbohydrates: 21,
        imageUrl: 'https://images.example.com/banana.jpg',
      },
    ]);
    const composite = ['Данонино ягода-банан', 'Венский завтрак банан', 'Хлопья банан', 'Смузи банан-клубника', 'Йогурт с бананом'];
    for (const name of composite) {
      await service.createOwn({ name, source: 'RAZVIT', basisUnit: 'g', calories: 100, protein: 3, fat: 2, carbohydrates: 15 });
    }
    // 5 составных совпадений — раньше это само по себе блокировало
    // обращение к внешним источникам (порог MIN_LOCAL_RESULTS_BEFORE_EXTERNAL_FETCH).

    const res = await searchService.search({ query: 'банан', page: 1, perPage: 20, sort: 'name' });

    expect(off.search).toHaveBeenCalled();
    expect(res.items[0]).toMatchObject({ name: 'Банан', source: 'OFF' });
  });

  it('не дёргает внешние источники повторно, если простой товар уже есть локально', async () => {
    const { service, off, searchService } = buildService();
    await service.createOwn({ name: 'Банан', source: 'RAZVIT', basisUnit: 'g', calories: 96, protein: 1.5, fat: 0.2, carbohydrates: 21 });
    // Достаточно совпадений (>= порога), чтобы проверить именно ветку
    // "есть сильное совпадение", а не более простую "мало результатов".
    const composite = ['Данонино ягода-банан', 'Венский завтрак банан', 'Хлопья банан', 'Смузи банан-клубника'];
    for (const name of composite) {
      await service.createOwn({ name, source: 'RAZVIT', basisUnit: 'g', calories: 100, protein: 3, fat: 2, carbohydrates: 15 });
    }

    await searchService.search({ query: 'банан', page: 1, perPage: 20, sort: 'name' });

    expect(off.search).not.toHaveBeenCalled();
  });
});
