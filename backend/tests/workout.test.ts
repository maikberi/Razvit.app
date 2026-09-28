import request from 'supertest';
import { createApp } from '../src/app';
import { pool } from '../src/db/pool';
import { runMigrations } from '../src/db/migrate';
import { newTestUser } from './testAuth';

const app = createApp();

const sampleProgram = {
  title: 'Моя программа',
  goal: 'mass',
  level: 'intermediate',
  totalWeeks: 8,
  trainingDays: [1, 3, 5],
  days: [
    {
      id: 'day_1',
      title: 'День 1',
      exercises: [
        { exerciseId: 'barbell-bench-press', exerciseName: 'Жим штанги лёжа', sets: 4, repsLabel: '8-10', weightKg: 60, restSeconds: 90 },
      ],
    },
  ],
};

function sampleSession(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    date: '2026-01-15T10:00:00Z',
    title: 'День 1',
    status: 'done',
    durationMinutes: 45,
    calories: 320,
    exerciseLogs: [
      {
        exerciseId: 'barbell-bench-press',
        exerciseName: 'Жим штанги лёжа',
        sets: [
          { weightKg: 60, reps: 8, completed: true },
          { weightKg: 60, reps: 8, completed: true },
        ],
      },
    ],
    ...overrides,
  };
}

beforeAll(async () => {
  await runMigrations();
});

beforeEach(async () => {
  await pool.query('TRUNCATE workout_sessions RESTART IDENTITY CASCADE');
  await pool.query('TRUNCATE workout_programs RESTART IDENTITY CASCADE');
});

afterAll(async () => {
  await pool.end();
});

describe('Workout persistence API', () => {
  it('POST /workout-programs без авторизации — 401', async () => {
    const res = await request(app).post('/api/v1/workout-programs').send(sampleProgram);
    expect(res.status).toBe(401);
  });

  it('создаёт свою программу и возвращает её в списке', async () => {
    const { header } = newTestUser();
    const create = await request(app).post('/api/v1/workout-programs').set(header).send(sampleProgram);
    expect(create.status).toBe(201);
    expect(create.body.data.title).toBe('Моя программа');
    expect(create.body.data.isCustom).toBe(true);
    expect(create.body.data.days).toHaveLength(1);
    expect(create.body.data.days[0].exercises[0].exerciseName).toBe('Жим штанги лёжа');

    const list = await request(app).get('/api/v1/workout-programs').set(header);
    expect(list.status).toBe(200);
    expect(list.body.data).toHaveLength(1);
  });

  it('POST /workout-programs без упражнений в дне — 422', async () => {
    const { header } = newTestUser();
    const invalid = { ...sampleProgram, days: [{ id: 'day_1', title: 'День 1', exercises: [] }] };
    const res = await request(app).post('/api/v1/workout-programs').set(header).send(invalid);
    expect(res.status).toBe(422);
  });

  it('программы одного пользователя не видны другому (SECURITY)', async () => {
    const userA = newTestUser();
    const userB = newTestUser();
    await request(app).post('/api/v1/workout-programs').set(userA.header).send(sampleProgram);

    const bList = await request(app).get('/api/v1/workout-programs').set(userB.header);
    expect(bList.body.data).toHaveLength(0);
  });

  it('удаляет свою программу, чужую — нельзя (SECURITY)', async () => {
    const userA = newTestUser();
    const userB = newTestUser();
    const create = await request(app).post('/api/v1/workout-programs').set(userA.header).send(sampleProgram);
    const id = create.body.data.id;

    const deleteByB = await request(app).delete(`/api/v1/workout-programs/${id}`).set(userB.header);
    expect(deleteByB.status).toBe(404);

    const deleteByA = await request(app).delete(`/api/v1/workout-programs/${id}`).set(userA.header);
    expect(deleteByA.status).toBe(204);
  });

  it('записывает завершённую тренировку и отдаёт её в истории', async () => {
    const { header } = newTestUser();
    const create = await request(app).post('/api/v1/workout-sessions').set(header).send(sampleSession());
    expect(create.status).toBe(201);
    expect(create.body.data.title).toBe('День 1');
    expect(create.body.data.exerciseLogs[0].sets).toHaveLength(2);

    const list = await request(app).get('/api/v1/workout-sessions').set(header);
    expect(list.status).toBe(200);
    expect(list.body.data).toHaveLength(1);
  });

  it('сессию со ссылкой на чужую программу создать нельзя (SECURITY)', async () => {
    const userA = newTestUser();
    const userB = newTestUser();
    const program = await request(app).post('/api/v1/workout-programs').set(userA.header).send(sampleProgram);

    const res = await request(app)
      .post('/api/v1/workout-sessions')
      .set(userB.header)
      .send(sampleSession({ programId: program.body.data.id }));
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('WORKOUT_PROGRAM_NOT_FOUND');
  });

  it('история тренировок одного пользователя не видна другому (SECURITY)', async () => {
    const userA = newTestUser();
    const userB = newTestUser();
    await request(app).post('/api/v1/workout-sessions').set(userA.header).send(sampleSession());

    const bList = await request(app).get('/api/v1/workout-sessions').set(userB.header);
    expect(bList.body.data).toHaveLength(0);
  });

  it('список сессий отсортирован по дате по убыванию (последняя тренировка первой)', async () => {
    const { header } = newTestUser();
    await request(app).post('/api/v1/workout-sessions').set(header).send(sampleSession({ date: '2026-01-01T10:00:00Z', title: 'Старая' }));
    await request(app).post('/api/v1/workout-sessions').set(header).send(sampleSession({ date: '2026-02-01T10:00:00Z', title: 'Новая' }));

    const list = await request(app).get('/api/v1/workout-sessions').set(header);
    expect(list.body.data.map((s: { title: string }) => s.title)).toEqual(['Новая', 'Старая']);
  });
});
