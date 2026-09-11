import { Pool } from 'pg';
import { SOCIAL_ID_COLUMNS, SocialProvider, UserRow } from './auth.model';

export class AuthRepository {
  constructor(private readonly pool: Pool) {}

  async create(email: string, passwordHash: string, name: string): Promise<UserRow> {
    const { rows } = await this.pool.query<UserRow>(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, $2, $3) RETURNING *`,
      [email, passwordHash, name],
    );
    return rows[0];
  }

  /** Создаёт пользователя, зашедшего через соцсеть (без пароля) —
   * колонка выбирается из фиксированного набора (SOCIAL_ID_COLUMNS),
   * никогда из пользовательского ввода, поэтому подстановка имени
   * колонки в SQL здесь безопасна. */
  async createFromSocial(provider: SocialProvider, email: string, name: string, socialId: string): Promise<UserRow> {
    const column = SOCIAL_ID_COLUMNS[provider];
    const { rows } = await this.pool.query<UserRow>(
      `INSERT INTO users (email, password_hash, name, ${column}) VALUES ($1, NULL, $2, $3) RETURNING *`,
      [email, name, socialId],
    );
    return rows[0];
  }

  async linkSocialId(provider: SocialProvider, userId: string, socialId: string): Promise<UserRow> {
    const column = SOCIAL_ID_COLUMNS[provider];
    const { rows } = await this.pool.query<UserRow>(`UPDATE users SET ${column} = $1 WHERE id = $2 RETURNING *`, [
      socialId,
      userId,
    ]);
    return rows[0];
  }

  async findBySocialId(provider: SocialProvider, socialId: string): Promise<UserRow | null> {
    const column = SOCIAL_ID_COLUMNS[provider];
    const { rows } = await this.pool.query<UserRow>(`SELECT * FROM users WHERE ${column} = $1`, [socialId]);
    return rows[0] ?? null;
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
