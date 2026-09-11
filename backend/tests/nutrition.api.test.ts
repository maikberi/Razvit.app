import request from 'supertest';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';

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

async function createFood(overrides: Record<string, unknown> = {}) {
  const res = await request(app)
    .post('/api/v1/foods')
    .send({
      name: 'Куриная грудка',
      calories: 165,
      protein: 31,
      fat: 3.6,
      carbohydrates: 0,
      sodium: 74,
      ...overrides,
    });
  return res.body.data as { id: string };
}

describe('Nutrition Engine API', () => {
  describe('POST /nutrition/calculate/food', () => {
    it('пример из ТЗ: курица 100г=165ккал, 200г запроса -> 330 ккал, белок 62г (по foodId)', async () => {
      const food = await createFood();
      const res = await request(app).post('/api/v1/nutrition/calculate/food').send({ foodId: food.id, grams: 200 });

      expect(res.status).toBe(200);
      expect(res.body.data.calories).toBe(330);
      expect(res.body.data.protein).toBe(62);
      expect(res.body.data.sodium).toBe(148);
    });

    it('работает и с ручными нутриентами (без foodId) — для продуктов, которых нет в базе', async () => {
      const res = await request(app)
        .post('/api/v1/nutrition/calculate/food')
        .send({ grams: 50, nutrients: { calories: 200, protein: 10, fat: 5, carbohydrates: 20, fiber: 2 } });

      expect(res.status).toBe(200);
      expect(res.body.data.calories).toBe(100);
      expect(res.body.data.protein).toBe(5);
    });

    it('возвращает поля calories/protein/fat/carbohydrates/fiber/sugar/sodium/micronutrients', async () => {
      const food = await createFood({ fiber: 0.5, sugar: 1.2 });
      const res = await request(app).post('/api/v1/nutrition/calculate/food').send({ foodId: food.id, grams: 100 });

      expect(res.body.data).toEqual(
        expect.objectContaining({
          calories: expect.any(Number),
          protein: expect.any(Number),
          fat: expect.any(Number),
          carbohydrates: expect.any(Number),
          fiber: expect.any(Number),
          sugar: expect.any(Number),
          sodium: expect.any(Number),
          micronutrients: expect.any(Object),
        }),
      );
    });

    it('404, если foodId не существует', async () => {
      const res = await request(app)
        .post('/api/v1/nutrition/calculate/food')
        .send({ foodId: '00000000-0000-0000-0000-000000000000', grams: 100 });
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('FOOD_NOT_FOUND');
    });

    it('422, если передать и foodId, и nutrients одновременно', async () => {
      const food = await createFood();
      const res = await request(app)
        .post('/api/v1/nutrition/calculate/food')
        .send({ foodId: food.id, nutrients: { calories: 1, protein: 1, fat: 1, carbohydrates: 1 }, grams: 100 });
      expect(res.status).toBe(422);
    });

    it('422, если не передать ни foodId, ни nutrients', async () => {
      const res = await request(app).post('/api/v1/nutrition/calculate/food').send({ grams: 100 });
      expect(res.status).toBe(422);
    });

    it('422 при отрицательных граммах', async () => {
      const food = await createFood();
      const res = await request(app).post('/api/v1/nutrition/calculate/food').send({ foodId: food.id, grams: -5 });
      expect(res.status).toBe(422);
    });

    it('0 г -> 0 по всем полям', async () => {
      const food = await createFood();
      const res = await request(app).post('/api/v1/nutrition/calculate/food').send({ foodId: food.id, grams: 0 });
      expect(res.body.data.calories).toBe(0);
      expect(res.body.data.protein).toBe(0);
    });
  });

  describe('POST /nutrition/calculate/meal', () => {
    it('считает сумму нескольких продуктов приёма пищи', async () => {
      const chicken = await createFood({ name: 'Курица' });
      const rice = await createFood({ name: 'Рис', calories: 112, protein: 2.6, fat: 0.9, carbohydrates: 23, sodium: 5 });

      const res = await request(app)
        .post('/api/v1/nutrition/calculate/meal')
        .send({
          items: [
            { foodId: chicken.id, grams: 150 },
            { foodId: rice.id, grams: 100 },
          ],
        });

      expect(res.status).toBe(200);
      // 165*1.5=247.5 + 112 = 359.5 -> 360 (округление до целого)
      expect(res.body.data.calories).toBe(360);
    });

    it('422 на пустой список items', async () => {
      const res = await request(app).post('/api/v1/nutrition/calculate/meal').send({ items: [] });
      expect(res.status).toBe(422);
    });
  });

  describe('POST /nutrition/calculate/recipe', () => {
    it('считает total и perServing', async () => {
      const dough = await createFood({ name: 'Тесто', calories: 265, protein: 9, fat: 3.2, carbohydrates: 49, sodium: 490 });
      const res = await request(app)
        .post('/api/v1/nutrition/calculate/recipe')
        .send({ items: [{ foodId: dough.id, grams: 400 }], servings: 4 });

      expect(res.status).toBe(200);
      expect(res.body.data.total.calories).toBe(1060); // 265*4
      expect(res.body.data.perServing.calories).toBe(265); // /4
    });

    it('servings по умолчанию 1', async () => {
      const dough = await createFood({ name: 'Тесто' });
      const res = await request(app).post('/api/v1/nutrition/calculate/recipe').send({ items: [{ foodId: dough.id, grams: 100 }] });
      expect(res.body.data.total).toEqual(res.body.data.perServing);
    });

    it('422 при servings <= 0', async () => {
      const dough = await createFood({ name: 'Тесто' });
      const res = await request(app)
        .post('/api/v1/nutrition/calculate/recipe')
        .send({ items: [{ foodId: dough.id, grams: 100 }], servings: 0 });
      expect(res.status).toBe(422);
    });
  });

  describe('POST /nutrition/calculate/day', () => {
    it('считает сумму по всем приёмам пищи за день', async () => {
      const chicken = await createFood({ name: 'Курица' });
      const res = await request(app)
        .post('/api/v1/nutrition/calculate/day')
        .send({
          meals: [{ items: [{ foodId: chicken.id, grams: 100 }] }, { items: [{ foodId: chicken.id, grams: 200 }] }],
        });

      expect(res.status).toBe(200);
      expect(res.body.data.calories).toBe(495); // 165 + 330
    });

    it('422 на пустой список meals', async () => {
      const res = await request(app).post('/api/v1/nutrition/calculate/day').send({ meals: [] });
      expect(res.status).toBe(422);
    });
  });

  describe('POST /nutrition/calculate/week', () => {
    it('считает total и dailyAverage по готовым дневным итогам', async () => {
      const res = await request(app)
        .post('/api/v1/nutrition/calculate/week')
        .send({
          days: [
            { calories: 2000, protein: 150, fat: 60, carbohydrates: 200, fiber: 25, sugar: 30, sodium: 2000, micronutrients: {} },
            { calories: 1800, protein: 140, fat: 55, carbohydrates: 180, fiber: 22, sugar: 25, sodium: 1800, micronutrients: {} },
          ],
        });

      expect(res.status).toBe(200);
      expect(res.body.data.total.calories).toBe(3800);
      expect(res.body.data.dailyAverage.calories).toBe(1900);
    });

    it('422 на пустой список days', async () => {
      const res = await request(app).post('/api/v1/nutrition/calculate/week').send({ days: [] });
      expect(res.status).toBe(422);
    });
  });
});
