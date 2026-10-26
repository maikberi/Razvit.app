import { Pool } from 'pg';
import { SOCIAL_ID_COLUMNS, SocialProvider, UserProfilePatch, UserRole, UserRow } from './auth.model';

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

  async findByIds(ids: string[]): Promise<UserRow[]> {
    if (ids.length === 0) return [];
    const { rows } = await this.pool.query<UserRow>(`SELECT * FROM users WHERE id = ANY($1::uuid[])`, [ids]);
    return rows;
  }

  async setRole(id: string, role: UserRole): Promise<UserRow> {
    const { rows } = await this.pool.query<UserRow>(`UPDATE users SET role = $1 WHERE id = $2 RETURNING *`, [role, id]);
    return rows[0];
  }

  /**
   * Обновляет только те поля, что реально присутствуют в patch — в отличие
   * от nutrition/workout-профилей (там COALESCE(new, old) на каждом поле),
   * здесь важно различать "поле не трогали" (undefined, ключа нет в теле
   * запроса) от "поле явно очистили" (null, например убрали никнейм или
   * фото) — простой COALESCE не умеет отличить null-очистку от "оставить
   * как было".
   */
  async updateProfile(id: string, patch: UserProfilePatch): Promise<UserRow> {
    const sets: string[] = [];
    const values: unknown[] = [];
    let i = 1;

    if (patch.name !== undefined) {
      sets.push(`name = $${i++}`);
      values.push(patch.name);
    }
    if (patch.lastName !== undefined) {
      sets.push(`last_name = $${i++}`);
      values.push(patch.lastName);
    }
    if (patch.nickname !== undefined) {
      sets.push(`nickname = $${i++}`);
      values.push(patch.nickname);
    }
    if (patch.avatarUrl !== undefined) {
      sets.push(`avatar_url = $${i++}`);
      values.push(patch.avatarUrl);
    }

    if (sets.length === 0) {
      const existing = await this.findById(id);
      return existing as UserRow;
    }

    values.push(id);
    const { rows } = await this.pool.query<UserRow>(
      `UPDATE users SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`,
      values,
    );
    return rows[0];
  }
}
