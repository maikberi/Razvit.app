import { Pool } from 'pg';
import { UserRow } from './auth.model';

export class AuthRepository {
  constructor(private readonly pool: Pool) {}

  async create(email: string, passwordHash: string, name: string): Promise<UserRow> {
    const { rows } = await this.pool.query<UserRow>(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, $2, $3) RETURNING *`,
      [email, passwordHash, name],
    );
    return rows[0];
  }

  async findByEmail(email: string): Promise<UserRow | null> {
    const { rows } = await this.pool.query<UserRow>(`SELECT * FROM users WHERE email = $1`, [email]);
    return rows[0] ?? null;
  }

  async findById(id: string): Promise<UserRow | null> {
    const { rows } = await this.pool.query<UserRow>(`SELECT * FROM users WHERE id = $1`, [id]);
    return rows[0] ?? null;
  }
}
