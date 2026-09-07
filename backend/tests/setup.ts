process.env.NODE_ENV = 'test';
import dotenv from 'dotenv';
dotenv.config();

import { runMigrations } from '../src/db/migrate';
import { env } from '../src/config/env';

beforeAll(async () => {
  await runMigrations(env.databaseUrl);
});
