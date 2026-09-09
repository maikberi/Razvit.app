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

  async createFromGoogle(email: string, name: string, googleId: string): Promise<UserRow> {
    const { rows } = await this.pool.query<UserRow>(
      `INSERT INTO users (email, password_hash, name, google_id) VALUES ($1, NULL, $2, $3) RETURNING *`,
      [email, name, googleId],
    );
    return rows[0];
  }

  async linkGoogleId(userId: string, googleId: string): Promise<UserRow> {
    const { rows } = await this.pool.query<UserRow>(`UPDATE users SET google_id = $1 WHERE id = $2 RETURNING *`, [
      googleId,
      userId,
    ]);
    return rows[0];
  }

  async findByEmail(email: string): Promise<UserRow | null> {
    const { rows } = await this.pool.query<UserRow>(`SELECT * FROM users WHERE email = $1`, [email]);
    return rows[0] ?? null;
  }

  async findByGoogleId(googleId: string): Promise<UserRow | null> {
    const { rows } = await this.pool.query<UserRow>(`SELECT * FROM users WHERE google_id = $1`, [googleId]);
    return rows[0] ?? null;
  }

  async findById(id: string): Promise<UserRow | null> {
    const { rows } = await this.pool.query<UserRow>(`SELECT * FROM users WHERE id = $1`, [id]);
    return rows[0] ?? null;
  }
}
