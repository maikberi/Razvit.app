import request from 'supertest';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { FoodRepository } from '../src/modules/food/food.repository';
import { FoodService } from '../src/modules/food/food.service';

const app = createApp();

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE foods RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

describe('Food Database API', () => {
  it('создаёт продукт (POST /foods)', async () => {
    const res = await request(app)
      .post('/api/v1/foods')
      .send({ name: 'Овсянка', calories: 68, protein: 2.4, fat: 1.4, carbohydrates: 12 });

    expect(res.status).toBe(201);
    expect(res.body.data.id).toBeDefined();
    expect(res.body.data.name).toBe('Овсянка');
    expect(res.body.data.caloriesPer100g).toBe(68);
    expect(res.body.data.source).toBe('RAZVIT');
  });

  it('отклоняет некорректные данные с 422 и деталями по полям', async () => {
    const res = await request(app)
      .post('/api/v1/foods')
      .send({ name: '', calories: -1, protein: 1, fat: 1, carbohydrates: 1 });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details).toHaveProperty('name');
    expect(res.body.error.details).toHaveProperty('calories');
  });

  it('получает продукт по id (GET /foods/:id)', async () => {
    const created = await request(app)
      .post('/api/v1/foods')
      .send({ name: 'Курица', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });

    const res = await request(app).get(`/api/v1/foods/${created.body.data.id}`);
    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe('Курица');
  });

  it('возвращает 404, если продукт по id не найден', async () => {
    const res = await request(app).get('/api/v1/foods/00000000-0000-0000-0000-000000000000');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('FOOD_NOT_FOUND');
  });

  it('возвращает 422 для невалидного (не-UUID) id', async () => {
    const res = await request(app).get('/api/v1/foods/not-a-uuid');
    expect(res.status).toBe(422);
  });

  it('находит продукт по штрихкоду (GET /foods/barcode/:barcode)', async () => {
    await request(app)
      .post('/api/v1/foods')
      .send({ name: 'Молоко', calories: 60, protein: 3, fat: 3.2, carbohydrates: 4.7, barcode: '4600000000100' });

    const res = await request(app).get('/api/v1/foods/barcode/4600000000100');
    expect(res.status).toBe(200);
    expect(res.body.data.barcode).toBe('4600000000100');
  });

  it('возвращает 404 для неизвестного штрихкода (внешний источник тоже не даёт результата)', async () => {
    const res = await request(app).get('/api/v1/foods/barcode/0000000000000');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('FOOD_NOT_FOUND');
  });

  describe('защита от дублей', () => {
    it('запрещает создать второй продукт с уже занятым штрихкодом (409)', async () => {
      const payload = { name: 'Йогурт', calories: 60, protein: 5, fat: 2, carbohydrates: 6, barcode: '4600000000099' };
      const first = await request(app).post('/api/v1/foods').send(payload);
      expect(first.status).toBe(201);

      const second = await request(app)
        .post('/api/v1/foods')
        .send({ ...payload, name: 'Йогурт (повтор)' });

      expect(second.status).toBe(409);
      expect(second.body.error.code).toBe('FOOD_DUPLICATE');
      expect(second.body.error.details.existing.id).toBe(first.body.data.id);
    });

    it('findOrCreateFromExternal не плодит копии одного товара из разных внешних источников', async () => {
      const repo = new FoodRepository(pool);
      const service = new FoodService(repo);
      const shared = {
        name: 'Протеиновый батончик',
        barcode: '4600000000200',
        basisUnit: 'g' as const,
        calories: 350,
        protein: 30,
        fat: 10,
        carbohydrates: 20,
      };

      const fromOff = await service.findOrCreateFromExternal({ ...shared, source: 'OFF', sourceId: 'off-1' });
      const fromUsda = await service.findOrCreateFromExternal({ ...shared, source: 'USDA', sourceId: 'usda-1' });
      const sameOffAgain = await service.findOrCreateFromExternal({ ...shared, source: 'OFF', sourceId: 'off-1' });

      expect(fromOff.created).toBe(true);
      expect(fromUsda.created).toBe(false);
      expect(sameOffAgain.created).toBe(false);
      expect(fromUsda.food.id).toBe(fromOff.food.id);
      expect(sameOffAgain.food.id).toBe(fromOff.food.id);

      const { rows } = await pool.query('SELECT COUNT(*) FROM foods WHERE barcode = $1', ['4600000000200']);
      expect(Number(rows[0].count)).toBe(1);
    });
  });

  describe('поиск', () => {
    it('ищет по (частичному) названию и возвращает пагинацию в meta', async () => {
      await request(app).post('/api/v1/foods').send({ name: 'Рис отварной', calories: 116, protein: 2.2, fat: 0.5, carbohydrates: 24 });
      await request(app).post('/api/v1/foods').send({ name: 'Рис бурый', calories: 110, protein: 2.6, fat: 0.9, carbohydrates: 23 });
      await request(app).post('/api/v1/foods').send({ name: 'Гречка', calories: 110, protein: 4.2, fat: 1.1, carbohydrates: 21.3 });

      const res = await request(app).get('/api/v1/foods').query({ q: 'рис' });
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBe(2);
      expect(res.body.meta).toMatchObject({ page: 1, perPage: 20, total: 2, totalPages: 1 });
    });

    it('находит по бренду', async () => {
      await request(app).post('/api/v1/foods').send({ name: 'Батончик', brand: 'RAZVIT Nutrition', calories: 300, protein: 20, fat: 8, carbohydrates: 30 });
      const res = await request(app).get('/api/v1/foods').query({ q: 'razvit nutrition' });
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBe(1);
    });

    it('находит опечатку/близкое совпадение (fuzzy search)', async () => {
      await request(app).post('/api/v1/foods').send({ name: 'Творог', calories: 121, protein: 18, fat: 5, carbohydrates: 1.8 });
      const res = await request(app).get('/api/v1/foods').query({ q: 'творок' }); // опечатка
      expect(res.status).toBe(200);
      expect(res.body.data.some((f: { name: string }) => f.name === 'Творог')).toBe(true);
    });

    it('пагинирует и сортирует результаты', async () => {
      for (let i = 0; i < 3; i++) {
        await request(app)
          .post('/api/v1/foods')
          .send({ name: `Тестовый продукт ${i}`, calories: 100 + i, protein: 1, fat: 1, carbohydrates: 1 });
      }
      const page1 = await request(app).get('/api/v1/foods').query({ q: 'тестовый продукт', perPage: 2, page: 1, sort: 'name' });
      expect(page1.body.data.length).toBe(2);
      expect(page1.body.meta.total).toBe(3);
      expect(page1.body.meta.totalPages).toBe(2);

      const page2 = await request(app).get('/api/v1/foods').query({ q: 'тестовый продукт', perPage: 2, page: 2, sort: 'name' });
      expect(page2.body.data.length).toBe(1);
    });

    it('фильтрует по category и source', async () => {
      await request(app).post('/api/v1/foods').send({ name: 'Яблоко', category: 'Фрукты', calories: 52, protein: 0.3, fat: 0.2, carbohydrates: 14 });
      await request(app).post('/api/v1/foods').send({ name: 'Банан', category: 'Фрукты', calories: 89, protein: 1.1, fat: 0.3, carbohydrates: 23 });
      await request(app).post('/api/v1/foods').send({ name: 'Курица гриль', category: 'Мясо', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });

      const res = await request(app).get('/api/v1/foods').query({ category: 'Фрукты' });
      expect(res.status).toBe(200);
      expect(res.body.data.length).toBe(2);
      expect(res.body.data.every((f: { category: string }) => f.category === 'Фрукты')).toBe(true);
    });
  });

  it('сохраняет расширяемые микронутриенты и алиасы', async () => {
    const created = await request(app)
      .post('/api/v1/foods')
      .send({
        name: 'Шпинат',
        calories: 23,
        protein: 2.9,
        fat: 0.4,
        carbohydrates: 3.6,
        micronutrients: [
          { key: 'iron', amount: 2.7, unit: 'mg' },
          { key: 'vitamin_c', amount: 28, unit: 'mg' },
        ],
        aliases: ['spinach'],
      });

    const res = await request(app).get(`/api/v1/foods/${created.body.data.id}`);
    expect(res.body.data.micronutrients).toEqual({
      iron: { amount: 2.7, unit: 'mg' },
      vitamin_c: { amount: 28, unit: 'mg' },
    });
  });
});
