import { Pool } from 'pg';
import { WorkoutProgramRow, WorkoutSessionRow } from './workout.model';
import { CreateProgramBody, CreateSessionBody } from './workout.validation';

export class WorkoutRepository {
  constructor(private readonly pool: Pool) {}

  async createProgram(userId: string, input: CreateProgramBody): Promise<WorkoutProgramRow> {
    const { rows } = await this.pool.query<WorkoutProgramRow>(
      `INSERT INTO workout_programs (user_id, title, goal, level, total_weeks, training_days, days)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [userId, input.title, input.goal, input.level, input.totalWeeks, input.trainingDays, JSON.stringify(input.days)],
    );
    return rows[0];
  }

  async listPrograms(userId: string): Promise<WorkoutProgramRow[]> {
    const { rows } = await this.pool.query<WorkoutProgramRow>(
      'SELECT * FROM workout_programs WHERE user_id = $1 ORDER BY created_at ASC',
      [userId],
    );
    return rows;
  }

  async findProgram(userId: string, id: string): Promise<WorkoutProgramRow | null> {
    const { rows } = await this.pool.query<WorkoutProgramRow>(
      'SELECT * FROM workout_programs WHERE id = $1 AND user_id = $2',
      [id, userId],
    );
    return rows[0] ?? null;
  }

  async deleteProgram(userId: string, id: string): Promise<void> {
    await this.pool.query('DELETE FROM workout_programs WHERE id = $1 AND user_id = $2', [id, userId]);
  }

  async createSession(userId: string, input: CreateSessionBody): Promise<WorkoutSessionRow> {
    const { rows } = await this.pool.query<WorkoutSessionRow>(
      `INSERT INTO workout_sessions (user_id, program_id, program_day_id, date, title, status, duration_minutes, calories, exercise_logs)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        userId,
        input.programId ?? null,
        input.programDayId ?? null,
        input.date,
        input.title,
        input.status,
        input.durationMinutes,
        input.calories,
        JSON.stringify(input.exerciseLogs),
      ],
    );
    return rows[0];
  }

  async listSessions(userId: string): Promise<WorkoutSessionRow[]> {
    const { rows } = await this.pool.query<WorkoutSessionRow>(
      'SELECT * FROM workout_sessions WHERE user_id = $1 ORDER BY date DESC',
      [userId],
    );
    return rows;
  }
}
