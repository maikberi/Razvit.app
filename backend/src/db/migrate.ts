import fs from 'node:fs';
import path from 'node:path';
import { Pool } from 'pg';
import { env } from '../config/env';

/**
 * Простой раннер SQL-миграций: применяет по порядку файлы из db/migrations,
 * которые ещё не были применены (отслеживается в таблице schema_migrations).
 * Без внешних зависимостей — этого достаточно для одного backend-сервиса.
 */
export async function runMigrations(databaseUrl: string = env.databaseUrl): Promise<void> {
  const pool = new Pool({ connectionString: databaseUrl });
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
      );
    `);

    const migrationsDir = path.resolve(__dirname, '../../db/migrations');
    const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();

    const { rows } = await pool.query<{ name: string }>('SELECT name FROM schema_migrations');
    const applied = new Set(rows.map((r) => r.name));

    for (const file of files) {
      if (applied.has(file)) continue;
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf-8');
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
        await client.query('COMMIT');
        // eslint-disable-next-line no-console
        console.log(`[migrate] applied ${file}`);
      } catch (err) {
        await client.query('ROLLBACK');
        throw new Error(`Migration ${file} failed: ${(err as Error).message}`);
      } finally {
        client.release();
      }
    }
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  runMigrations()
    .then(() => {
      console.log('[migrate] done');
      process.exit(0);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
