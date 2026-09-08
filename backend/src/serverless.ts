import serverlessHttp from 'serverless-http';
import { createApp } from './app';
import { runMigrations } from './db/migrate';

const app = createApp();
const httpHandler = serverlessHttp(app);

// Миграции гоняем максимум раз на "холодный старт" контейнера функции
// (а не при каждом вызове) — так же, как раньше npm run migrate перед
// стартом сервера на Render, только здесь нет отдельного шага деплоя.
let migrationsDone: Promise<void> | null = null;

export const handler = async (event: Record<string, unknown>, context: Record<string, unknown>) => {
  if (!migrationsDone) {
    migrationsDone = runMigrations().catch((err) => {
      migrationsDone = null; // дать шанс повторить на следующем вызове, если БД была временно недоступна
      throw err;
    });
  }
  await migrationsDone;
  return httpHandler(event, context);
};
