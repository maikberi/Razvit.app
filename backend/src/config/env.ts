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
  // PEM-содержимое корневого сертификата для SSL-подключения к БД (нужен
  // для Yandex Managed PostgreSQL — она принимает соединения только по TLS).
  // Не обязателен для хостингов без такого требования (например Render).
  databaseSslCa: process.env.DATABASE_SSL_CA,
  jwtSecret: isTest ? (process.env.JWT_SECRET ?? 'test-secret-not-for-production') : required('JWT_SECRET'),
  // Client ID OAuth-приложения Google (console.cloud.google.com) — нужен
  // для проверки id-токена при входе через Google. Необязателен: без него
  // просто недоступен POST /auth/google, остальной вход работает как обычно.
  googleClientId: process.env.GOOGLE_CLIENT_ID,
  // ID приложения VK ID (id.vk.com) и его Сервисный ключ доступа — нужны
  // для обмена authorization code на данные пользователя (POST /auth/vk).
  // Именно "Сервисный ключ доступа" (service_token), а не "Защищённый
  // ключ" — так требует VK ID API для конфиденциальных приложений.
  // Тоже необязательны — без них этот способ входа просто недоступен.
  vkClientId: process.env.VK_CLIENT_ID,
  vkServiceToken: process.env.VK_SERVICE_TOKEN,
  // Токен бота из @BotFather (secret!) — нужен для проверки подписи
  // Telegram Login (POST /auth/telegram). Необязателен по той же схеме.
  telegramBotToken: process.env.TELEGRAM_BOT_TOKEN,
  // Пароль для разового наполнения каталога продуктами из Open Food Facts
  // (GET /admin/import/off-russia?key=...). Без этой переменной эндпоинт
  // всегда отвечает 403 — так что по умолчанию он выключен.
  adminImportKey: process.env.ADMIN_IMPORT_KEY,
};
