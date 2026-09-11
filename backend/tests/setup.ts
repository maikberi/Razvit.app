process.env.NODE_ENV = 'test';
import dotenv from 'dotenv';
dotenv.config();

// Миграции здесь намеренно НЕ запускаются: часть тестов (например,
// nutrition.calculation.test.ts) — чистые unit-тесты без базы данных
// вообще. Тесты, которым реально нужна БД, сами вызывают runMigrations
// в своём beforeAll (см. food.test.ts, nutrition.api.test.ts).
