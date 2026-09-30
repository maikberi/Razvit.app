import request from 'supertest';
import { randomUUID } from 'crypto';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { FoodRepository } from '../src/modules/food/food.repository';
import { FoodMatchingService } from '../src/modules/food/food.matching';
import { NutritionCalculationService } from '../src/modules/nutrition/nutrition.calculation.service';
import { RecipeGeneratorService } from '../src/modules/recipeGenerator/recipeGenerator.service';
import { RecipeDraft } from '../src/integrations/recipeGeneratorClient';
import { authHeaderForUser, newTestUser } from './testAuth';

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

describe('POST /recipe-generator/generate (HTTP-уровень, без реального AI)', () => {
  it('без авторизации — 401', async () => {
    const res = await request(app).post('/api/v1/recipe-generator/generate').send({ prompt: 'Хочу ужин до 600 ккал' });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('без prompt — 422', async () => {
    const { header } = newTestUser();
    const res = await request(app).post('/api/v1/recipe-generator/generate').set(header).send({});
    expect(res.status).toBe(422);
    expect(res.body.error.details).toHaveProperty('prompt');
  });

  it('без настроенного ANTHROPIC_API_KEY — 503 AI_NOT_CONFIGURED (реальный путь через RecipeGeneratorClient)', async () => {
    const { header } = newTestUser();
    const res = await request(app)
      .post('/api/v1/recipe-generator/generate')
      .set(header)
      .send({ prompt: 'Хочу лёгкий ужин с курицей' });
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('AI_NOT_CONFIGURED');
  });
});

describe('RecipeGeneratorService (с фейковым RecipeGeneratorClient — без реального обращения к Anthropic)', () => {
  async function createFood(overrides: Record<string, unknown> = {}) {
    const res = await request(app)
      .post('/api/v1/foods').set(authHeaderForUser(randomUUID()))
      .send({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0, ...overrides });
    return res.body.data as { id: string };
  }

  function buildService(drafts: RecipeDraft | RecipeDraft[]) {
    const repo = new FoodRepository(pool);
    const matching = new FoodMatchingService(repo);
    const engine = new NutritionCalculationService();
    const sequence = Array.isArray(drafts) ? drafts : [drafts];
    const generate = jest.fn();
    for (const d of sequence) generate.mockResolvedValueOnce(d);
    if (sequence.length === 1) generate.mockResolvedValue(sequence[0]); // повторные вызовы (если есть) возвращают тот же черновик
    const fakeClient = { generate };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return { service: new RecipeGeneratorService(fakeClient as any, matching, engine), generate };
  }

  const baseDraft = (overrides: Partial<RecipeDraft> = {}): RecipeDraft => ({
    name: 'Куриная грудка на пару',
    description: 'Простой белковый ужин',
    servings: 1,
    cookingTimeMinutes: 20,
    instructions: 'Отварить куриную грудку на пару 20 минут.',
    ingredients: [{ name: 'куриная грудка', quantity: 150, unit: 'g' }],
    ...overrides,
  });

  it('AI придумывает рецепт, ингредиенты находятся в базе — нутриенты считает Nutrition Engine, а не AI', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    const { service } = buildService(baseDraft());

    const recipe = await service.generate('Хочу простой куриный ужин');

    expect(recipe.name).toBe('Куриная грудка на пару');
    expect(recipe.ingredients).toHaveLength(1);
    expect(recipe.ingredients[0].matchedFoodName).toBe('Куриная грудка');
    expect(recipe.ingredients[0].matchTier).toBe('exact');
    // 165 ккал/100г * 150г / 100 = 247.5 -> округление Nutrition Engine до 248
    expect(recipe.nutrition.perServing.calories).toBe(248);
    expect(recipe.nutrition.perServing.protein).toBeCloseTo(46.5, 1);
    expect(recipe.constraints).toBeNull();
    expect(recipe.constraintsSatisfied).toBe(true);
    expect(recipe.adjustmentNote).toBeNull();
    expect(recipe.hasUnresolvedIngredients).toBe(false);
  });

  it('ингредиент не найден в базе — hasUnresolvedIngredients=true, он не участвует в расчёте КБЖУ', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    const { service } = buildService(
      baseDraft({
        ingredients: [
          { name: 'куриная грудка', quantity: 150, unit: 'g' },
          { name: 'совершенно неизвестный ингредиент xyz', quantity: 50, unit: 'g' },
        ],
      }),
    );

    const recipe = await service.generate('Ужин с курицей');

    expect(recipe.ingredients).toHaveLength(2);
    expect(recipe.ingredients[1].matchedFoodId).toBeNull();
    expect(recipe.hasUnresolvedIngredients).toBe(true);
    // КБЖУ — только от куриной грудки, неизвестный ингредиент не посчитан.
    expect(recipe.nutrition.perServing.calories).toBe(248);
  });

  it('AI превысил лимит калорий — backend уменьшает порцию (пересчитывает), чтобы уложиться в ограничение, без повторного обращения к AI', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    const { service, generate } = buildService(
      baseDraft({ constraints: { maxCalories: 200 } }),
    );

    const recipe = await service.generate('Хочу ужин до 200 ккал');

    expect(generate).toHaveBeenCalledTimes(1); // пересчитали пропорционально, повторная генерация не понадобилась
    expect(recipe.nutrition.perServing.calories).toBeLessThanOrEqual(200);
    expect(recipe.constraintsSatisfied).toBe(true);
    expect(recipe.adjustmentNote).toContain('Уменьшили порцию');
    // Ингредиент тоже должен быть уменьшен пропорционально (был 150 г).
    expect(recipe.ingredients[0].quantity).toBeLessThan(150);
  });

  it('пропорциональный пересчёт невозможен (противоречивые ограничения) — одна повторная генерация с обратной связью, второй вариант укладывается', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    await createFood({ name: 'Творог обезжиренный', calories: 71, protein: 18, fat: 0.6, carbohydrates: 1.5 });

    const constraints = { maxCalories: 200, minProtein: 50 };
    const { service, generate } = buildService([
      baseDraft({ constraints }), // 150г курицы: 247.5 ккал / 46.5 г белка — невозможно одновременно уложиться в 200 ккал и добрать 50 г белка одним коэффициентом
      baseDraft({
        name: 'Творог с обратной связью от AI',
        ingredients: [{ name: 'творог обезжиренный', quantity: 280, unit: 'g' }],
        constraints,
      }),
    ]);

    const recipe = await service.generate('Хочу ужин до 200 ккал и минимум 50 г белка');

    expect(generate).toHaveBeenCalledTimes(2);
    const [, secondCallArgs] = generate.mock.calls;
    expect(secondCallArgs[1]).toEqual(expect.any(String)); // обратная связь передана вторым аргументом

    expect(recipe.name).toBe('Творог с обратной связью от AI');
    expect(recipe.nutrition.perServing.calories).toBeLessThanOrEqual(200);
    expect(recipe.nutrition.perServing.protein).toBeGreaterThanOrEqual(50);
    expect(recipe.constraintsSatisfied).toBe(true);
  });

  it('даже после повторной генерации ограничения физически недостижимы — принимаем ближайший вариант с constraintsSatisfied=false', async () => {
    await createFood({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    const { service, generate } = buildService(baseDraft({ constraints: { minProtein: 1000 } }));

    const recipe = await service.generate('Хочу ужин минимум с 1000 г белка');

    expect(generate).toHaveBeenCalledTimes(2); // первая попытка + одна повторная, дальше не пытаемся бесконечно
    expect(recipe.constraintsSatisfied).toBe(false);
    expect(recipe.adjustmentNote).toContain('Не удалось');
  });
});
