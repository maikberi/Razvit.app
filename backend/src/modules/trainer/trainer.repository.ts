import { Pool } from 'pg';
import {
  CoachCommentRow,
  CoachMealAssignmentInput,
  CoachMealAssignmentRow,
  CoachNutritionPlanPatch,
  CoachNutritionPlanRow,
  TrainerClientRow,
  TrainerClientStatus,
} from './trainer.model';

export class TrainerRepository {
  constructor(private readonly pool: Pool) {}

  // ---- trainer_clients ----

  async findRelation(trainerId: string, clientId: string): Promise<TrainerClientRow | null> {
    const { rows } = await this.pool.query<TrainerClientRow>(
      'SELECT * FROM trainer_clients WHERE trainer_id = $1 AND client_id = $2',
      [trainerId, clientId],
    );
    return rows[0] ?? null;
  }

  async findById(id: string): Promise<TrainerClientRow | null> {
    const { rows } = await this.pool.query<TrainerClientRow>('SELECT * FROM trainer_clients WHERE id = $1', [id]);
    return rows[0] ?? null;
  }

  async createInvite(trainerId: string, clientId: string): Promise<TrainerClientRow> {
    const { rows } = await this.pool.query<TrainerClientRow>(
      `INSERT INTO trainer_clients (trainer_id, client_id, status) VALUES ($1, $2, 'pending') RETURNING *`,
      [trainerId, clientId],
    );
    return rows[0];
  }

  async updateStatus(id: string, status: TrainerClientStatus): Promise<TrainerClientRow> {
    const { rows } = await this.pool.query<TrainerClientRow>(
      'UPDATE trainer_clients SET status = $1 WHERE id = $2 RETURNING *',
      [status, id],
    );
    return rows[0];
  }

  async listClientsForTrainer(trainerId: string, status: TrainerClientStatus = 'approved'): Promise<TrainerClientRow[]> {
    const { rows } = await this.pool.query<TrainerClientRow>(
      'SELECT * FROM trainer_clients WHERE trainer_id = $1 AND status = $2 ORDER BY updated_at DESC',
      [trainerId, status],
    );
    return rows;
  }

  async listPendingInvitesForClient(clientId: string): Promise<TrainerClientRow[]> {
    const { rows } = await this.pool.query<TrainerClientRow>(
      `SELECT * FROM trainer_clients WHERE client_id = $1 AND status = 'pending' ORDER BY created_at DESC`,
      [clientId],
    );
    return rows;
  }

  async listTrainersForClient(clientId: string, status: TrainerClientStatus = 'approved'): Promise<TrainerClientRow[]> {
    const { rows } = await this.pool.query<TrainerClientRow>(
      'SELECT * FROM trainer_clients WHERE client_id = $1 AND status = $2 ORDER BY updated_at DESC',
      [clientId, status],
    );
    return rows;
  }

  // ---- coach_nutrition_plans ----

  async findPlanForClient(clientId: string): Promise<CoachNutritionPlanRow | null> {
    const { rows } = await this.pool.query<CoachNutritionPlanRow>(
      'SELECT * FROM coach_nutrition_plans WHERE client_id = $1',
      [clientId],
    );
    return rows[0] ?? null;
  }

  async upsertPlan(clientId: string, trainerId: string, patch: CoachNutritionPlanPatch): Promise<CoachNutritionPlanRow> {
    const { rows } = await this.pool.query<CoachNutritionPlanRow>(
      `INSERT INTO coach_nutrition_plans (client_id, trainer_id, title, calorie_target, protein_target, notes)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (client_id) DO UPDATE SET
         trainer_id = EXCLUDED.trainer_id,
         title = EXCLUDED.title,
         calorie_target = EXCLUDED.calorie_target,
         protein_target = EXCLUDED.protein_target,
         notes = EXCLUDED.notes
       RETURNING *`,
      [clientId, trainerId, patch.title ?? null, patch.calorieTarget ?? null, patch.proteinTarget ?? null, patch.notes ?? null],
    );
    return rows[0];
  }

  // ---- coach_meal_assignments ----

  async createAssignment(trainerId: string, clientId: string, input: CoachMealAssignmentInput): Promise<CoachMealAssignmentRow> {
    const { rows } = await this.pool.query<CoachMealAssignmentRow>(
      `INSERT INTO coach_meal_assignments (trainer_id, client_id, recipe_id, title, notes, meal_type)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [trainerId, clientId, input.recipeId ?? null, input.title, input.notes ?? null, input.mealType ?? null],
    );
    return rows[0];
  }

  async listAssignmentsForClient(clientId: string): Promise<CoachMealAssignmentRow[]> {
    const { rows } = await this.pool.query<CoachMealAssignmentRow>(
      'SELECT * FROM coach_meal_assignments WHERE client_id = $1 ORDER BY created_at DESC',
      [clientId],
    );
    return rows;
  }

  async findAssignmentById(id: string): Promise<CoachMealAssignmentRow | null> {
    const { rows } = await this.pool.query<CoachMealAssignmentRow>('SELECT * FROM coach_meal_assignments WHERE id = $1', [id]);
    return rows[0] ?? null;
  }

  async deleteAssignment(id: string): Promise<void> {
    await this.pool.query('DELETE FROM coach_meal_assignments WHERE id = $1', [id]);
  }

  // ---- coach_comments ----

  async createComment(trainerId: string, clientId: string, message: string): Promise<CoachCommentRow> {
    const { rows } = await this.pool.query<CoachCommentRow>(
      'INSERT INTO coach_comments (trainer_id, client_id, message) VALUES ($1, $2, $3) RETURNING *',
      [trainerId, clientId, message],
    );
    return rows[0];
  }

  async listCommentsForClient(clientId: string): Promise<CoachCommentRow[]> {
    const { rows } = await this.pool.query<CoachCommentRow>(
      'SELECT * FROM coach_comments WHERE client_id = $1 ORDER BY created_at DESC',
      [clientId],
    );
    return rows;
  }
}
