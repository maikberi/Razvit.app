import { AuthRepository } from '../auth/auth.repository';
import { ForbiddenError } from '../meal/meal.service';
import { NutritionAnalyticsResult, AnalyticsPeriod } from '../nutrition/nutritionAnalytics.model';
import { NutritionAnalyticsService } from '../nutrition/nutritionAnalytics.service';
import { DailySummary } from '../nutrition/nutrition.daily.service';
import { NutritionDailyService } from '../nutrition/nutrition.daily.service';
import { NutritionTargetsRepository, TargetsRow } from '../nutrition/nutrition.targets.repository';
import { RecipeNotFoundError } from '../recipe/recipe.service';
import { RecipeRepository } from '../recipe/recipe.repository';
import {
  CoachCommentRow,
  CoachMealAssignmentInput,
  CoachMealAssignmentRow,
  CoachNutritionPlanPatch,
  CoachNutritionPlanRow,
  TrainerClientRow,
  TrainerRelationWithCounterpart,
} from './trainer.model';
import { TrainerAccessService } from './trainer.access.service';
import { TrainerRepository } from './trainer.repository';

export class ClientNotFoundError extends Error {
  constructor() {
    super('No user with this email');
    this.name = 'ClientNotFoundError';
  }
}

export class CannotInviteSelfError extends Error {
  constructor() {
    super('Cannot invite yourself');
    this.name = 'CannotInviteSelfError';
  }
}

export class AlreadyConnectedError extends Error {
  constructor() {
    super('Already connected to this client');
    this.name = 'AlreadyConnectedError';
  }
}

export class TrainerRelationNotFoundError extends Error {
  constructor() {
    super('Trainer-client relation not found');
    this.name = 'TrainerRelationNotFoundError';
  }
}

export class InvalidRelationStateError extends Error {
  constructor(message = 'This invite was already responded to') {
    super(message);
    this.name = 'InvalidRelationStateError';
  }
}

export class AssignmentNotFoundError extends Error {
  constructor() {
    super('Meal assignment not found');
    this.name = 'AssignmentNotFoundError';
  }
}

/**
 * Оркестрирует связь тренер-клиент (приглашения/подтверждение/отзыв) и
 * всё, что тренер назначает клиенту (Daily Target, Assigned Meals, Coach
 * Comments). Каждый метод, где тренер трогает данные КОНКРЕТНОГО клиента,
 * начинается с TrainerAccessService.assertApproved — это единственная
 * проверка доступа во всём модуле, и обойти её нельзя ни из Flutter, ни
 * подделав clientId в URL (см. SECURITY в ЭТАП 17).
 */
export class TrainerService {
  constructor(
    private readonly repo: TrainerRepository,
    private readonly access: TrainerAccessService,
    private readonly authRepo: AuthRepository,
    private readonly recipeRepo: RecipeRepository,
    private readonly dailyService: NutritionDailyService,
    private readonly analyticsService: NutritionAnalyticsService,
    private readonly targetsRepo: NutritionTargetsRepository,
  ) {}

  async becomeTrainer(userId: string): Promise<void> {
    await this.authRepo.setRole(userId, 'trainer');
  }

  // ---- Связь тренер-клиент ----

  async inviteClient(trainerId: string, clientEmail: string): Promise<TrainerClientRow> {
    const client = await this.authRepo.findByEmail(clientEmail);
    if (!client) throw new ClientNotFoundError();
    if (client.id === trainerId) throw new CannotInviteSelfError();

    const existing = await this.repo.findRelation(trainerId, client.id);
    if (existing) {
      if (existing.status === 'approved') throw new AlreadyConnectedError();
      return this.repo.updateStatus(existing.id, 'pending');
    }
    return this.repo.createInvite(trainerId, client.id);
  }

  async listMyClients(trainerId: string): Promise<TrainerRelationWithCounterpart[]> {
    const relations = await this.repo.listClientsForTrainer(trainerId, 'approved');
    return this.withCounterparts(relations, (r) => r.client_id);
  }

  async listMyInvites(clientId: string): Promise<TrainerRelationWithCounterpart[]> {
    const relations = await this.repo.listPendingInvitesForClient(clientId);
    return this.withCounterparts(relations, (r) => r.trainer_id);
  }

  async listMyTrainers(clientId: string): Promise<TrainerRelationWithCounterpart[]> {
    const relations = await this.repo.listTrainersForClient(clientId, 'approved');
    return this.withCounterparts(relations, (r) => r.trainer_id);
  }

  /** Подтягивает {id,email,name} другой стороны для списка связей одним батч-запросом (не N+1). */
  private async withCounterparts(
    relations: TrainerClientRow[],
    idOf: (row: TrainerClientRow) => string,
  ): Promise<TrainerRelationWithCounterpart[]> {
    const ids = [...new Set(relations.map(idOf))];
    const users = await this.authRepo.findByIds(ids);
    const byId = new Map(users.map((u) => [u.id, u]));
    return relations.map((relation) => {
      const user = byId.get(idOf(relation));
      return { relation, counterpart: user ? { id: user.id, email: user.email, name: user.name } : null };
    });
  }

  /** Только клиент, которому адресовано приглашение, может его принять/отклонить. */
  async respondToInvite(clientId: string, relationId: string, approve: boolean): Promise<TrainerClientRow> {
    const relation = await this.repo.findById(relationId);
    if (!relation) throw new TrainerRelationNotFoundError();
    if (relation.client_id !== clientId) throw new ForbiddenError();
    if (relation.status !== 'pending') throw new InvalidRelationStateError();
    return this.repo.updateStatus(relationId, approve ? 'approved' : 'declined');
  }

  /** Отозвать связь может любая из двух сторон — и тренер, и клиент. */
  async revokeRelation(userId: string, relationId: string): Promise<void> {
    const relation = await this.repo.findById(relationId);
    if (!relation) throw new TrainerRelationNotFoundError();
    if (relation.client_id !== userId && relation.trainer_id !== userId) throw new ForbiddenError();
    await this.repo.updateStatus(relationId, 'revoked');
  }

  // ---- Тренер читает данные клиента (доступ проверяется первым делом) ----

  async getClientDaily(trainerId: string, clientId: string, date: string): Promise<DailySummary> {
    await this.access.assertApproved(trainerId, clientId);
    return this.dailyService.getDaily(clientId, date);
  }

  async getClientAnalytics(trainerId: string, clientId: string, period: AnalyticsPeriod): Promise<NutritionAnalyticsResult> {
    await this.access.assertApproved(trainerId, clientId);
    return this.analyticsService.getAnalytics(clientId, period);
  }

  async getClientGoals(trainerId: string, clientId: string): Promise<TargetsRow> {
    await this.access.assertApproved(trainerId, clientId);
    return this.targetsRepo.getOrCreateDefault(clientId);
  }

  // ---- Тренер назначает клиенту (доступ проверяется первым делом) ----

  async setClientPlan(trainerId: string, clientId: string, patch: CoachNutritionPlanPatch): Promise<CoachNutritionPlanRow> {
    await this.access.assertApproved(trainerId, clientId);
    return this.repo.upsertPlan(clientId, trainerId, patch);
  }

  async assignMeal(trainerId: string, clientId: string, input: CoachMealAssignmentInput): Promise<CoachMealAssignmentRow> {
    await this.access.assertApproved(trainerId, clientId);
    if (input.recipeId) {
      const recipe = await this.recipeRepo.findById(input.recipeId);
      if (!recipe) throw new RecipeNotFoundError();
    }
    return this.repo.createAssignment(trainerId, clientId, input);
  }

  /** Убрать назначение может только тренер, который его создал. */
  async removeAssignment(trainerId: string, assignmentId: string): Promise<void> {
    const row = await this.repo.findAssignmentById(assignmentId);
    if (!row) throw new AssignmentNotFoundError();
    if (row.trainer_id !== trainerId) throw new ForbiddenError();
    await this.repo.deleteAssignment(assignmentId);
  }

  async addComment(trainerId: string, clientId: string, message: string): Promise<CoachCommentRow> {
    await this.access.assertApproved(trainerId, clientId);
    return this.repo.createComment(trainerId, clientId, message);
  }

  // ---- Клиент читает СВОИ данные (доступ не проверяется — это всегда его же userId) ----

  async getMyCoachPlan(clientId: string): Promise<CoachNutritionPlanRow | null> {
    return this.repo.findPlanForClient(clientId);
  }

  async getMyAssignments(clientId: string): Promise<CoachMealAssignmentRow[]> {
    return this.repo.listAssignmentsForClient(clientId);
  }

  async getMyComments(clientId: string): Promise<CoachCommentRow[]> {
    return this.repo.listCommentsForClient(clientId);
  }
}
