import serverlessHttp from 'serverless-http';
import { createApp } from './app';
import { runMigrations } from './db/migrate';

const app = createApp();
const httpHandler = serverlessHttp(app);

// Миграции гоняем максимум раз на "холодный старт" контейнера функции
// (а не при каждом вызове) — так же, как раньше npm run migrate перед
// стартом сервера на Render, только здесь нет отдельного шага деплоя.
let migrationsDone: Promise<void> | null = null;

/**
 * При проксировании через Yandex API Gateway (спецификация с /{proxy+})
 * event.path приходит как буквальный шаблон "/{proxy+}", а реальный
 * запрошенный путь лежит в event.pathParams.proxy (без ведущего слэша)
 * либо в event.url. serverless-http (формат событий AWS) ожидает
 * настоящий путь в event.path — подменяем его перед передачей туда.
 */
function resolveRequestPath(event: Record<string, unknown>): string {
  const pathParams = event.pathParams as Record<string, string> | undefined;
  if (pathParams && typeof pathParams.proxy === 'string') {
    return `/${pathParams.proxy}`;
  }
  if (typeof event.url === 'string' && event.url.length > 0) {
    return event.url.split('?')[0];
  }
  if (typeof event.path === 'string' && event.path.length > 0) {
    return event.path;
  }
  return '/';
}

export const handler = async (event: Record<string, unknown>, context: Record<string, unknown>) => {
  if (!migrationsDone) {
    migrationsDone = runMigrations().catch((err) => {
      migrationsDone = null; // дать шанс повторить на следующем вызове, если БД была временно недоступна
      throw err;
    });
  }
  await migrationsDone;
  const normalizedEvent = { ...event, path: resolveRequestPath(event) };
  return httpHandler(normalizedEvent, context);
};
