import request from 'supertest';
import { randomUUID } from 'crypto';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';

const app = createApp();

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query(
    'TRUNCATE users, foods, meals, recipes, nutrition_targets, trainer_clients, coach_nutrition_plans, coach_meal_assignments, coach_comments RESTART IDENTITY CASCADE',
  );
});

afterAll(async () => {
  await pool.end();
});

/** У этого пользователя не будет строки в users (как и везде в проекте — user_id без FK), поэтому email должен быть реальным пользователем для findByEmail; регистрируем через /auth/register. */
async function registerUser(email: string) {
  const res = await request(app).post('/api/v1/auth/register').send({ email, password: 'password123', name: 'Test' });
  return { id: res.body.data.user.id as string, token: res.body.data.token as string };
}

function tokenHeader(token: string) {
  return { Authorization: `Bearer ${token}` };
}

async function connectTrainerAndClient(trainerEmail: string, clientEmail: string) {
  const trainer = await registerUser(trainerEmail);
  const client = await registerUser(clientEmail);
  const invite = await request(app).post('/api/v1/trainer/clients/invite').set(tokenHeader(trainer.token)).send({ email: clientEmail });
  const relationId = invite.body.data.id as string;
  await request(app).post(`/api/v1/trainer/invites/${relationId}/respond`).set(tokenHeader(client.token)).send({ approve: true });
  return { trainer, client, relationId };
}

describe('Trainer <-> Client связь (приглашения)', () => {
  it('без авторизации — 401', async () => {
    const res = await request(app).get('/api/v1/trainer/clients');
    expect(res.status).toBe(401);
  });

  it('полный цикл: приглашение -> клиент видит в invites -> принимает -> тренер видит в clients', async () => {
    const trainer = await registerUser('trainer1@test.com');
    const client = await registerUser('client1@test.com');

    const invite = await request(app)
      .post('/api/v1/trainer/clients/invite')
      .set(tokenHeader(trainer.token))
      .send({ email: 'client1@test.com' });
    expect(invite.status).toBe(201);
    expect(invite.body.data.status).toBe('pending');

    const invites = await request(app).get('/api/v1/trainer/invites').set(tokenHeader(client.token));
    expect(invites.body.data).toHaveLength(1);
    expect(invites.body.data[0].trainerId).toBe(trainer.id);

    const respond = await request(app)
      .post(`/api/v1/trainer/invites/${invite.body.data.id}/respond`)
      .set(tokenHeader(client.token))
      .send({ approve: true });
    expect(respond.status).toBe(200);
    expect(respond.body.data.status).toBe('approved');

    const clients = await request(app).get('/api/v1/trainer/clients').set(tokenHeader(trainer.token));
    expect(clients.body.data).toHaveLength(1);
    expect(clients.body.data[0].clientId).toBe(client.id);
    expect(clients.body.data[0].counterpart).toEqual({ id: client.id, email: 'client1@test.com', name: 'Test' });

    const trainers = await request(app).get('/api/v1/trainer/my-trainers').set(tokenHeader(client.token));
    expect(trainers.body.data).toHaveLength(1);
    expect(trainers.body.data[0].trainerId).toBe(trainer.id);
    expect(trainers.body.data[0].counterpart.email).toBe('trainer1@test.com');
  });

  it('приглашение на несуществующий email — 404 CLIENT_NOT_FOUND', async () => {
    const trainer = await registerUser('trainer2@test.com');
    const res = await request(app)
      .post('/api/v1/trainer/clients/invite')
      .set(tokenHeader(trainer.token))
      .send({ email: 'nobody-such-user@test.com' });
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('CLIENT_NOT_FOUND');
  });

  it('приглашение самого себя — 422 CANNOT_INVITE_SELF', async () => {
    const trainer = await registerUser('trainer3@test.com');
    const res = await request(app).post('/api/v1/trainer/clients/invite').set(tokenHeader(trainer.token)).send({ email: 'trainer3@test.com' });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('CANNOT_INVITE_SELF');
  });

  it('повторное приглашение уже approved-клиента — 409 ALREADY_CONNECTED', async () => {
    const { trainer } = await connectTrainerAndClient('trainer4@test.com', 'client4@test.com');
    const res = await request(app).post('/api/v1/trainer/clients/invite').set(tokenHeader(trainer.token)).send({ email: 'client4@test.com' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ALREADY_CONNECTED');
  });

  it('ответить на чужое приглашение нельзя — 403', async () => {
    const trainer = await registerUser('trainer5@test.com');
    const client = await registerUser('client5@test.com');
    const stranger = await registerUser('stranger5@test.com');

    const invite = await request(app).post('/api/v1/trainer/clients/invite').set(tokenHeader(trainer.token)).send({ email: 'client5@test.com' });
    const res = await request(app)
      .post(`/api/v1/trainer/invites/${invite.body.data.id}/respond`)
      .set(tokenHeader(stranger.token))
      .send({ approve: true });
    expect(res.status).toBe(403);
  });

  it('отклонённое приглашение отвечать повторно нельзя — 409', async () => {
    const trainer = await registerUser('trainer6@test.com');
    const client = await registerUser('client6@test.com');
    const invite = await request(app).post('/api/v1/trainer/clients/invite').set(tokenHeader(trainer.token)).send({ email: 'client6@test.com' });
    await request(app).post(`/api/v1/trainer/invites/${invite.body.data.id}/respond`).set(tokenHeader(client.token)).send({ approve: false });

    const res = await request(app)
      .post(`/api/v1/trainer/invites/${invite.body.data.id}/respond`)
      .set(tokenHeader(client.token))
      .send({ approve: true });
    expect(res.status).toBe(409);
  });
});

describe('SECURITY: тренер видит только связанных и подтверждённых клиентов', () => {
  async function createFood() {
    const res = await request(app)
      .post('/api/v1/foods')
      .send({ name: 'Куриная грудка', calories: 165, protein: 31, fat: 3.6, carbohydrates: 0 });
    return res.body.data as { id: string };
  }

  it('тренер без ЛЮБОЙ связи с пользователем — 403 при попытке посмотреть его дневник', async () => {
    const trainer = await registerUser('t-nolink@test.com');
    const randomPerson = await registerUser('random-person@test.com');

    const res = await request(app).get(`/api/v1/trainer/clients/${randomPerson.id}/daily`).set(tokenHeader(trainer.token));
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('TRAINER_ACCESS_DENIED');
  });

  it('связь ещё pending (не принята клиентом) — тренер всё равно не видит данные', async () => {
    const trainer = await registerUser('t-pending@test.com');
    const client = await registerUser('c-pending@test.com');
    await request(app).post('/api/v1/trainer/clients/invite').set(tokenHeader(trainer.token)).send({ email: 'c-pending@test.com' });

    const res = await request(app).get(`/api/v1/trainer/clients/${client.id}/daily`).set(tokenHeader(trainer.token));
    expect(res.status).toBe(403);
  });

  it('клиент A не должен быть виден тренеру, подключённому только к клиенту B', async () => {
    const { trainer } = await connectTrainerAndClient('t-ab@test.com', 'client-b@test.com');
    const clientA = await registerUser('client-a-unrelated@test.com'); // не связан с этим тренером

    const res = await request(app).get(`/api/v1/trainer/clients/${clientA.id}/daily`).set(tokenHeader(trainer.token));
    expect(res.status).toBe(403);
  });

  it('после revoke связь больше не даёт доступа', async () => {
    const { trainer, client, relationId } = await connectTrainerAndClient('t-revoke@test.com', 'c-revoke@test.com');

    const before = await request(app).get(`/api/v1/trainer/clients/${client.id}/daily`).set(tokenHeader(trainer.token));
    expect(before.status).toBe(200);

    const revoke = await request(app).delete(`/api/v1/trainer/relations/${relationId}`).set(tokenHeader(client.token));
    expect(revoke.status).toBe(204);

    const after = await request(app).get(`/api/v1/trainer/clients/${client.id}/daily`).set(tokenHeader(trainer.token));
    expect(after.status).toBe(403);
  });

  it('approved-тренер видит daily/analytics/goals подключённого клиента', async () => {
    const { trainer, client } = await connectTrainerAndClient('t-view@test.com', 'c-view@test.com');
    const chicken = await createFood();
    const day = await request(app).get('/api/v1/meals').set(tokenHeader(client.token)).query({ date: '2026-01-20' });
    await request(app).post(`/api/v1/meals/${day.body.data.meals[0].id}/items`).set(tokenHeader(client.token)).send({ foodId: chicken.id, grams: 200 });

    const daily = await request(app).get(`/api/v1/trainer/clients/${client.id}/daily`).set(tokenHeader(trainer.token)).query({ date: '2026-01-20' });
    expect(daily.status).toBe(200);
    expect(daily.body.data.consumed.calories).toBe(330);

    const analytics = await request(app).get(`/api/v1/trainer/clients/${client.id}/analytics`).set(tokenHeader(trainer.token)).query({ period: '7d' });
    expect(analytics.status).toBe(200);

    const goals = await request(app).get(`/api/v1/trainer/clients/${client.id}/goals`).set(tokenHeader(trainer.token));
    expect(goals.status).toBe(200);
    expect(goals.body.data.calorieGoal).toBeGreaterThan(0);
  });
});

describe('Тренер назначает клиенту: Daily Target, Assigned Meals, Coach Comments', () => {
  it('PUT plan (calorie/protein target) — клиент видит его в GET /trainer/coach-plan', async () => {
    const { trainer, client } = await connectTrainerAndClient('t-plan@test.com', 'c-plan@test.com');

    const set = await request(app)
      .put(`/api/v1/trainer/clients/${client.id}/plan`)
      .set(tokenHeader(trainer.token))
      .send({ title: 'План на похудение', calorieTarget: 1800, proteinTarget: 140 });
    expect(set.status).toBe(200);
    expect(set.body.data.calorieTarget).toBe(1800);

    const mine = await request(app).get('/api/v1/trainer/coach-plan').set(tokenHeader(client.token));
    expect(mine.status).toBe(200);
    expect(mine.body.data.title).toBe('План на похудение');
    expect(mine.body.data.proteinTarget).toBe(140);
  });

  it('POST meal-assignment (без рецепта) — клиент видит в GET /trainer/meal-assignments', async () => {
    const { trainer, client } = await connectTrainerAndClient('t-assign@test.com', 'c-assign@test.com');

    const created = await request(app)
      .post(`/api/v1/trainer/clients/${client.id}/meal-assignments`)
      .set(tokenHeader(trainer.token))
      .send({ title: 'Овсянка с ягодами на завтрак', mealType: 'breakfast' });
    expect(created.status).toBe(201);

    const mine = await request(app).get('/api/v1/trainer/meal-assignments').set(tokenHeader(client.token));
    expect(mine.body.data).toHaveLength(1);
    expect(mine.body.data[0].title).toBe('Овсянка с ягодами на завтрак');
    expect(mine.body.data[0].trainerId).toBe(trainer.id);
  });

  it('POST meal-assignment с несуществующим recipeId — 404 RECIPE_NOT_FOUND', async () => {
    const { trainer, client } = await connectTrainerAndClient('t-badrecipe@test.com', 'c-badrecipe@test.com');
    const res = await request(app)
      .post(`/api/v1/trainer/clients/${client.id}/meal-assignments`)
      .set(tokenHeader(trainer.token))
      .send({ title: 'Что-то', recipeId: randomUUID() });
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('RECIPE_NOT_FOUND');
  });

  it('удалить назначение может только тренер, который его создал', async () => {
    const { trainer, client } = await connectTrainerAndClient('t-owner@test.com', 'c-owner@test.com');
    const otherTrainer = await registerUser('t-other@test.com');
    // otherTrainer тоже подключается к тому же клиенту.
    const invite2 = await request(app).post('/api/v1/trainer/clients/invite').set(tokenHeader(otherTrainer.token)).send({ email: 'c-owner@test.com' });
    await request(app).post(`/api/v1/trainer/invites/${invite2.body.data.id}/respond`).set(tokenHeader(client.token)).send({ approve: true });

    const created = await request(app)
      .post(`/api/v1/trainer/clients/${client.id}/meal-assignments`)
      .set(tokenHeader(trainer.token))
      .send({ title: 'Назначение первого тренера' });

    const deleteByOther = await request(app).delete(`/api/v1/trainer/meal-assignments/${created.body.data.id}`).set(tokenHeader(otherTrainer.token));
    expect(deleteByOther.status).toBe(403);

    const deleteByOwner = await request(app).delete(`/api/v1/trainer/meal-assignments/${created.body.data.id}`).set(tokenHeader(trainer.token));
    expect(deleteByOwner.status).toBe(204);
  });

  it('POST comment — клиент видит в GET /trainer/coach-comments', async () => {
    const { trainer, client } = await connectTrainerAndClient('t-comment@test.com', 'c-comment@test.com');
    const created = await request(app)
      .post(`/api/v1/trainer/clients/${client.id}/comments`)
      .set(tokenHeader(trainer.token))
      .send({ message: 'Отличная неделя, продолжай в том же духе!' });
    expect(created.status).toBe(201);

    const mine = await request(app).get('/api/v1/trainer/coach-comments').set(tokenHeader(client.token));
    expect(mine.body.data).toHaveLength(1);
    expect(mine.body.data[0].message).toBe('Отличная неделя, продолжай в том же духе!');
  });

  it('тренер без approved-связи не может ни назначить план, ни оставить комментарий', async () => {
    const trainer = await registerUser('t-noaccess@test.com');
    const client = await registerUser('c-noaccess@test.com');

    const plan = await request(app).put(`/api/v1/trainer/clients/${client.id}/plan`).set(tokenHeader(trainer.token)).send({ calorieTarget: 1800 });
    expect(plan.status).toBe(403);

    const comment = await request(app)
      .post(`/api/v1/trainer/clients/${client.id}/comments`)
      .set(tokenHeader(trainer.token))
      .send({ message: 'Привет' });
    expect(comment.status).toBe(403);
  });
});
