import { Pool } from 'pg';
import { env } from '../config/env';
import { pgSslConfig } from './ssl';

export const pool = new Pool({ connectionString: env.databaseUrl, ssl: pgSslConfig() });
