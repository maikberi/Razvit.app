import request from 'supertest';
import { randomUUID } from 'crypto';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { newTestUser } from './testAuth';

const app = createApp();

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE foods, recipes RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

async function createFood(overrides: Record<string, unknown> = {}) {
  const res = await request(app)
    .post('/api/v1/foods')
    .send({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0, ...overrides });
  return res.body.data as { id: string };
}

describe('Recipe API', () => {
  it('без авторизации — 401', async () => {
    const res = await request(app).get('/api/v1/recipes');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  describe('CRUD', () => {
    it('создаёт рецепт и считает нутриенты (total и perServing) из ингредиентов', async () => {
      const { header } = newTestUser();
      const chicken = await createFood({ name: 'Курица', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
      const rice = await createFood({ name: 'Рис отварной', calories: 116, protein: 2.2, fat: 0.5, carbohydrates: 24 });

      const res = await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({
          name: 'Курица с рисом',
          description: 'Простой обед',
          servings: 2,
          cookingTimeMinutes: 30,
          instructions: 'Отварить рис. Обжарить курицу. Смешать.',
          ingredients: [
            { foodId: chicken.id, quantity: 300, unit: 'g' },
            { foodId: rice.id, quantity: 200, unit: 'g' },
          ],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.name).toBe('Курица с рисом');
      expect(res.body.data.isOwner).toBe(true);
      expect(res.body.data.isFavorite).toBe(false);
      expect(res.body.data.ingredients).toHaveLength(2);

      // 300г курицы (165ккал/100г) + 200г риса (116ккал/100г) = 495 + 232 = 727
      expect(res.body.data.nutrition.total.calories).toBe(727);
      expect(res.body.data.nutrition.perServing.calories).toBe(364); // 727/2, округлено
    });

    it('не хранит nutrition руками — пересчитывает при изменении ингредиентов (edit)', async () => {
      const { header } = newTestUser();
      const chicken = await createFood({ calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
      const created = await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({
          name: 'Курица соло',
          servings: 1,
          instructions: 'Пожарить',
          ingredients: [{ foodId: chicken.id, quantity: 100, unit: 'g' }],
        });
      expect(created.body.data.nutrition.total.calories).toBe(165);

      const rice = await createFood({ name: 'Рис', calories: 116, protein: 2.2, fat: 0.5, carbohydrates: 24 });
      const updated = await request(app)
        .put(`/api/v1/recipes/${created.body.data.id}`)
        .set(header)
        .send({
          name: 'Курица с рисом',
          servings: 1,
          instructions: 'Пожарить, отварить',
          ingredients: [
            { foodId: chicken.id, quantity: 100, unit: 'g' },
            { foodId: rice.id, quantity: 100, unit: 'g' },
          ],
        });

      expect(updated.status).toBe(200);
      expect(updated.body.data.nutrition.total.calories).toBe(281); // 165 + 116, пересчитано заново
      expect(updated.body.data.ingredients).toHaveLength(2);
    });

    it('получает рецепт по id со всеми ингредиентами', async () => {
      const { header } = newTestUser();
      const food = await createFood();
      const created = await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({ name: 'Тест', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });

      const res = await request(app).get(`/api/v1/recipes/${created.body.data.id}`).set(header);
      expect(res.status).toBe(200);
      expect(res.body.data.name).toBe('Тест');
    });

    it('возвращает 404 для несуществующего рецепта', async () => {
      const { header } = newTestUser();
      const res = await request(app).get(`/api/v1/recipes/${randomUUID()}`).set(header);
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('RECIPE_NOT_FOUND');
    });

    it('отклоняет рецепт без ингредиентов (422)', async () => {
      const { header } = newTestUser();
      const res = await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({ name: 'Пусто', servings: 1, instructions: 'x', ingredients: [] });
      expect(res.status).toBe(422);
    });

    it('удаляет рецепт (204), после удаления недоступен', async () => {
      const { header } = newTestUser();
      const food = await createFood();
      const created = await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({ name: 'Удаляемый', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });

      const del = await request(app).delete(`/api/v1/recipes/${created.body.data.id}`).set(header);
      expect(del.status).toBe(204);

      const getAfter = await request(app).get(`/api/v1/recipes/${created.body.data.id}`).set(header);
      expect(getAfter.status).toBe(404);
    });
  });

  describe('владение (только автор может редактировать/удалять)', () => {
    it('чужой пользователь получает 403 на PUT и DELETE', async () => {
      const owner = newTestUser();
      const stranger = newTestUser();
      const food = await createFood();
      const created = await request(app)
        .post('/api/v1/recipes')
        .set(owner.header)
        .send({ name: 'Моё', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });

      const putRes = await request(app)
        .put(`/api/v1/recipes/${created.body.data.id}`)
        .set(stranger.header)
        .send({ name: 'Чужое', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });
      expect(putRes.status).toBe(403);

      const delRes = await request(app).delete(`/api/v1/recipes/${created.body.data.id}`).set(stranger.header);
      expect(delRes.status).toBe(403);
    });

    it('isOwner=false и чужой рецепт всё равно можно просматривать (GET/список)', async () => {
      const owner = newTestUser();
      const stranger = newTestUser();
      const food = await createFood();
      const created = await request(app)
        .post('/api/v1/recipes')
        .set(owner.header)
        .send({ name: 'Общий рецепт', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });

      const res = await request(app).get(`/api/v1/recipes/${created.body.data.id}`).set(stranger.header);
      expect(res.status).toBe(200);
      expect(res.body.data.isOwner).toBe(false);
    });
  });

  describe('избранное', () => {
    it('добавляет и убирает рецепт из избранного, идемпотентно', async () => {
      const { header } = newTestUser();
      const food = await createFood();
      const created = await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({ name: 'Любимый', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });
      const id = created.body.data.id;

      const fav1 = await request(app).post(`/api/v1/recipes/${id}/favorite`).set(header);
      expect(fav1.status).toBe(204);
      const fav2 = await request(app).post(`/api/v1/recipes/${id}/favorite`).set(header); // повторно — не падает
      expect(fav2.status).toBe(204);

      const afterFav = await request(app).get(`/api/v1/recipes/${id}`).set(header);
      expect(afterFav.body.data.isFavorite).toBe(true);

      const unfav = await request(app).delete(`/api/v1/recipes/${id}/favorite`).set(header);
      expect(unfav.status).toBe(204);
      const afterUnfav = await request(app).get(`/api/v1/recipes/${id}`).set(header);
      expect(afterUnfav.body.data.isFavorite).toBe(false);
    });

    it('favoriteOnly=true в списке возвращает только избранные рецепты этого пользователя', async () => {
      const { header } = newTestUser();
      const food = await createFood();
      const r1 = await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({ name: 'Рецепт 1', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });
      await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({ name: 'Рецепт 2', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });

      await request(app).post(`/api/v1/recipes/${r1.body.data.id}/favorite`).set(header);

      const res = await request(app).get('/api/v1/recipes').set(header).query({ favoriteOnly: 'true' });
      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].name).toBe('Рецепт 1');
    });
  });

  describe('единицы измерения ингредиентов', () => {
    it('pcs переводится в граммы через serving_size продукта', async () => {
      const { header } = newTestUser();
      // 1 яйцо = 50 г, 155 ккал/100г
      const egg = await createFood({ name: 'Яйцо', calories: 155, protein: 13, fat: 11, carbohydrates: 1.1, servingSize: 50 });

      const res = await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({ name: 'Яичница', servings: 1, instructions: 'Пожарить', ingredients: [{ foodId: egg.id, quantity: 2, unit: 'pcs' }] });

      expect(res.status).toBe(201);
      expect(res.body.data.ingredients[0].grams).toBe(100); // 2 * 50
      expect(res.body.data.nutrition.total.calories).toBe(155); // 100г при 155ккал/100г
    });

    it('pcs у продукта без serving_size — понятная ошибка 422', async () => {
      const { header } = newTestUser();
      const food = await createFood({ name: 'Без порции' }); // без servingSize

      const res = await request(app)
        .post('/api/v1/recipes')
        .set(header)
        .send({ name: 'Рецепт', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 2, unit: 'pcs' }] });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('RECIPE_INGREDIENT_UNIT_UNSUPPORTED');
    });
  });

  describe('поиск и пагинация', () => {
    it('фильтрует по имени (q) и поддерживает mine', async () => {
      const mine = newTestUser();
      const other = newTestUser();
      const food = await createFood();
      await request(app)
        .post('/api/v1/recipes')
        .set(mine.header)
        .send({ name: 'Овсянка с бананом', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });
      await request(app)
        .post('/api/v1/recipes')
        .set(other.header)
        .send({ name: 'Салат Цезарь', servings: 1, instructions: 'x', ingredients: [{ foodId: food.id, quantity: 100, unit: 'g' }] });

      const byName = await request(app).get('/api/v1/recipes').set(mine.header).query({ q: 'овсянка' });
      expect(byName.body.data).toHaveLength(1);
      expect(byName.body.data[0].name).toBe('Овсянка с бананом');

      const onlyMine = await request(app).get('/api/v1/recipes').set(mine.header).query({ mine: 'true' });
      expect(onlyMine.body.data).toHaveLength(1);
      expect(onlyMine.body.data.every((r: { isOwner: boolean }) => r.isOwner)).toBe(true);

      const all = await request(app).get('/api/v1/recipes').set(mine.header);
      expect(all.body.data).toHaveLength(2);
    });
  });
});
