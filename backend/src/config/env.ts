import dotenv from 'dotenv';

dotenv.config();

/**
 * Единая точка чтения переменных окружения. Никаких секретов/ключей
 * в коде — только отсюда. Если обязательная переменная не задана —
 * падаем сразу при старте (лучше, чем непонятная ошибка позже).
 */
function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Environment variable ${name} is required but not set`);
  }
  return value;
}

const isTest = process.env.NODE_ENV === 'test';

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 3000),
  databaseUrl: isTest
    ? (process.env.TEST_DATABASE_URL ?? required('DATABASE_URL'))
    : required('DATABASE_URL'),
  usdaApiKey: process.env.USDA_API_KEY ?? '',
  openFoodFactsBaseUrl: process.env.OPEN_FOOD_FACTS_BASE_URL ?? 'https://world.openfoodfacts.org',
};
