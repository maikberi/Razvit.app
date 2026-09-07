# RAZVIT backend — Food Database

Первый модуль backend'а RAZVIT: поиск продуктов, штрихкоды, собственная
база продуктов + продукты из USDA FoodData Central и Open Food Facts
(запросы к ним идут только с backend, ключей во Flutter нет).

## Что нужно, чтобы запустить локально

1. PostgreSQL 14+ (расширения `pgcrypto` и `pg_trgm` — накатываются миграцией сами).
2. Node.js 20+.
3. Скопировать `.env.example` в `.env` и подставить свою строку подключения к БД:
   ```
   cp .env.example .env
   ```
   `USDA_API_KEY` можно оставить пустым — тогда поиск просто не подключает
   USDA (это не ошибка), работает по своей базе + Open Food Facts.

## Команды

```bash
npm install       # установить зависимости
npm run migrate   # накатить SQL-миграции (db/migrations) на БД из DATABASE_URL
npm run dev       # запустить сервер в режиме разработки (порт из .env, по умолчанию 3000)
npm run build     # собрать в dist/ (для продакшена)
npm start         # запустить собранную версию (после npm run build)
npm test          # прогнать тесты (нужна отдельная TEST_DATABASE_URL — миграции применяются автоматически)
```

## Структура

```
src/
  config/env.ts              — чтение переменных окружения
  db/                         — пул соединений + раннер миграций
  integrations/               — клиенты USDA и Open Food Facts (только backend их вызывает)
  middleware/                 — валидация запросов, обработка ошибок
  modules/food/                — Food Database: model/repository/service/search/controller/routes
db/migrations/                — SQL-миграции (применяются по порядку, отслеживаются в schema_migrations)
tests/                         — Jest + Supertest
```

## API (кратко)

- `GET /api/v1/foods?q=&page=&perPage=&sort=&category=&source=` — поиск/список с пагинацией
- `GET /api/v1/foods/:id` — продукт по id
- `GET /api/v1/foods/barcode/:barcode` — поиск по штрихкоду
- `POST /api/v1/foods` — создать свой продукт (409, если штрихкод уже занят)

Формат ответа и ошибок, статус-коды — см. комментарии в
`src/middleware/errorHandler.ts` и `src/modules/food/food.controller.ts`.
