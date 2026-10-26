import { env } from '../config/env';

/**
 * SSL-настройки для подключения к PostgreSQL. Если задан DATABASE_SSL_CA
 * (нужно для Yandex Managed PostgreSQL), проверяем сертификат сервера по
 * нему. Иначе — без TLS-настроек, как раньше (например для Render).
 */
export function pgSslConfig(): { ca: string; rejectUnauthorized: true } | undefined {
  if (!env.databaseSslCa) return undefined;
  return { ca: env.databaseSslCa, rejectUnauthorized: true };
}
