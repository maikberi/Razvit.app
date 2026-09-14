import request from 'supertest';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { FoodRepository } from '../src/modules/food/food.repository';
import { FoodMatchingService } from '../src/modules/food/food.matching';
import { FoodRecognitionService } from '../src/modules/foodRecognition/foodRecognition.service';
import { NutritionCalculationService } from '../src/modules/nutrition/nutrition.calculation.service';
import { VisionRecognitionResult } from '../src/integrations/visionClient';
import { newTestUser } from './testAuth';

const app = createApp();

// Крошечный валидный PNG (1x1, прозрачный) — реальные magic bytes,
// достаточно, чтобы пройти проверку формата на backend.
const TINY_PNG_BASE64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE foods RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

describe('POST /food-recognition/scan (HTTP-уровень, без реального Vision AI)', () => {
  it('без авторизации — 401', async () => {
    const res = await request(app).post('/api/v1/food-recognition/scan').send({ imageBase64: TINY_PNG_BASE64, mimeType: 'image/png' });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('без imageBase64/mimeType — 422', async () => {
    const { header } = newTestUser();
    const res = await request(app).post('/api/v1/food-recognition/scan').set(header).send({});
    expect(res.status).toBe(422);
    expect(res.body.error.details).toHaveProperty('imageBase64');
    expect(res.body.error.details).toHaveProperty('mimeType');
  });

  it('содержимое не соответствует заявленному mimeType — 422 INVALID_IMAGE', async () => {
    const { header } = newTestUser();
    // Это PNG, но заявляем jpeg — magic bytes не совпадут.
    const res = await request(app)
      .post('/api/v1/food-recognition/scan')
      .set(header)
      .send({ imageBase64: TINY_PNG_BASE64, mimeType: 'image/jpeg' });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('INVALID_IMAGE');
  });

  it('без настроенного ANTHROPIC_API_KEY — 503 AI_NOT_CONFIGURED (реальный путь через VisionClient)', async () => {
    const { header } = newTestUser();
    const res = await request(app)
      .post('/api/v1/food-recognition/scan')
      .set(header)
      .send({ imageBase64: TINY_PNG_BASE64, mimeType: 'image/png' });
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('AI_NOT_CONFIGURED');
  });
});

describe('FoodRecognitionService (с фейковым VisionClient — без реального обращения к Anthropic)', () => {
  async function createFood(overrides: Record<string, unknown> = {}) {
    const res = await request(app)
      .post('/api/v1/foods')
      .send({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0, ...overrides });
    return res.body.data as { id: string };
  }

  function buildService(recognition: VisionRecognitionResult) {
    const repo = new FoodRepository(pool);
    const matching = new FoodMatchingService(repo);
    const engine = new NutritionCalculationService();
    const fakeVision = { recognizeFood: jest.fn().mockResolvedValue(recognition) };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return new FoodRecognitionService(fakeVision as any, matching, engine);
  }

  it('AI называет продукт — Database даёт КБЖУ на 100г, Nutrition Engine считает на вес порции (не AI считает калории)', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    const service = buildService({
      items: [{ name: 'куриная грудка', estimated_grams: 180, confidence: 0.91 }],
    });

    const result = await service.scan(TINY_PNG_BASE64, 'image/png');

    expect(result.items).toHaveLength(1);
    const item = result.items[0];
    expect(item.aiName).toBe('куриная грудка');
    expect(item.estimatedGrams).toBe(180);
    expect(item.confidence).toBe(0.91);
    expect(item.matchedFoodId).not.toBeNull();
    expect(item.matchedFoodName).toBe('Куриная грудка');
    // 165 ккал/100г * 180г / 100 = 297 — посчитано Nutrition Engine из данных базы, а не придумано AI.
    expect(item.nutrition).not.toBeNull();
    expect(item.nutrition!.calories).toBe(297);
    expect(item.nutrition!.protein).toBeCloseTo(55.8, 1);
  });

  it('продукт не найден в базе — nutrition остаётся null (AI не источник истины для КБЖУ)', async () => {
    const service = buildService({
      items: [{ name: 'совершенно неизвестное блюдо xyz123', estimated_grams: 200, confidence: 0.4 }],
    });

    const result = await service.scan(TINY_PNG_BASE64, 'image/png');

    expect(result.items).toHaveLength(1);
    expect(result.items[0].matchedFoodId).toBeNull();
    expect(result.items[0].nutrition).toBeNull();
  });

  it('пустой список items — валидный результат "еда не обнаружена", не ошибка', async () => {
    const service = buildService({ items: [], notes: 'На фото не видно еды' });
    const result = await service.scan(TINY_PNG_BASE64, 'image/png');
    expect(result.items).toEqual([]);
    expect(result.notes).toBe('На фото не видно еды');
  });

  it('несколько продуктов на фото — каждый сопоставляется независимо', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    await createFood({ name: 'Рис отварной', calories: 116, protein: 2.2, fat: 0.5, carbohydrates: 24 });
    const service = buildService({
      items: [
        { name: 'куриная грудка', estimated_grams: 150, confidence: 0.9 },
        { name: 'рис отварной', estimated_grams: 200, confidence: 0.85, possible_alternatives: ['гречка'] },
      ],
    });

    const result = await service.scan(TINY_PNG_BASE64, 'image/png');

    expect(result.items).toHaveLength(2);
    expect(result.items[0].matchedFoodName).toBe('Куриная грудка');
    expect(result.items[1].matchedFoodName).toBe('Рис отварной');
    expect(result.items[1].possibleAlternatives).toEqual(['гречка']);
    // 165*1.5 + 116*2 = 247.5 + 232 = 479.5 -> округление до целого в Nutrition Engine
    expect(result.items[0].nutrition!.calories + result.items[1].nutrition!.calories).toBeCloseTo(480, 0);
  });

  it('точное совпадение по названию + высокая уверенность AI — needsConfirmation=false, tier=exact', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    const service = buildService({
      items: [{ name: 'куриная грудка', estimated_grams: 180, confidence: 0.91 }],
    });

    const result = await service.scan(TINY_PNG_BASE64, 'image/png');

    expect(result.items[0].matchTier).toBe('exact');
    expect(result.items[0].matchScore).toBe(1);
    expect(result.items[0].needsConfirmation).toBe(false);
  });

  it('точное совпадение, но низкая уверенность AI — всё равно needsConfirmation=true', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    const service = buildService({
      items: [{ name: 'куриная грудка', estimated_grams: 180, confidence: 0.4 }],
    });

    const result = await service.scan(TINY_PNG_BASE64, 'image/png');

    expect(result.items[0].matchTier).toBe('exact');
    expect(result.items[0].needsConfirmation).toBe(true);
  });

  it('совпадение по алиасу — tier=alias, при высокой уверенности не требует подтверждения', async () => {
    await createFood({
      name: 'Куриная грудка',
      calories: 165,
      protein: 31,
      fat: 3.6,
      carbohydrates: 0,
      aliases: ['chicken breast'],
    });
    const service = buildService({
      items: [{ name: 'chicken breast', estimated_grams: 180, confidence: 0.88 }],
    });

    const result = await service.scan(TINY_PNG_BASE64, 'image/png');

    expect(result.items[0].matchTier).toBe('alias');
    expect(result.items[0].matchedFoodName).toBe('Куриная грудка');
    expect(result.items[0].needsConfirmation).toBe(false);
    expect(result.items[0].nutrition!.calories).toBe(297);
  });

  it('нечёткое совпадение (опечатка) — tier=fuzzy, всегда требует подтверждения, даже при высокой уверенности AI', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    const service = buildService({
      items: [{ name: 'куриная грудк', estimated_grams: 180, confidence: 0.95 }],
    });

    const result = await service.scan(TINY_PNG_BASE64, 'image/png');

    expect(result.items[0].matchTier).toBe('fuzzy');
    expect(result.items[0].needsConfirmation).toBe(true);
  });

  it('совпадение по категории — tier=category, требует подтверждения', async () => {
    await createFood({ name: 'Яблоко', category: 'Фрукты', calories: 52, protein: 0.3, fat: 0.2, carbohydrates: 14 });
    const service = buildService({
      items: [{ name: 'фрукты', estimated_grams: 100, confidence: 0.6 }],
    });

    const result = await service.scan(TINY_PNG_BASE64, 'image/png');

    expect(result.items[0].matchTier).toBe('category');
    expect(result.items[0].needsConfirmation).toBe(true);
  });

  it('совпадений не найдено — matchTier=null, matchScore=null, needsConfirmation=true', async () => {
    const service = buildService({
      items: [{ name: 'совершенно неизвестное блюдо xyz123', estimated_grams: 200, confidence: 0.9 }],
    });

    const result = await service.scan(TINY_PNG_BASE64, 'image/png');

    expect(result.items[0].matchTier).toBeNull();
    expect(result.items[0].matchScore).toBeNull();
    expect(result.items[0].needsConfirmation).toBe(true);
  });
});
