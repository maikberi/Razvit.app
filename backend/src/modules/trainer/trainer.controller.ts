import { asyncHandler } from '../../utils/asyncHandler';
import { TargetsRow } from '../nutrition/nutrition.targets.repository';
import {
  AssignmentIdParam,
  ClientAnalyticsQuery,
  ClientDateQuery,
  ClientIdParam,
  CreateAssignmentBody,
  CreateCommentBody,
  InviteClientBody,
  RelationIdParam,
  RespondInviteBody,
  SetCoachPlanBody,
} from './trainer.validation';
import { CoachCommentRow, CoachMealAssignmentRow, CoachNutritionPlanRow, TrainerClientRow, TrainerRelationWithCounterpart } from './trainer.model';
import { TrainerService } from './trainer.service';

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function serializeRelation(row: TrainerClientRow) {
  return {
    id: row.id,
    trainerId: row.trainer_id,
    clientId: row.client_id,
    status: row.status,
    sharePhotos: row.share_photos,
    createdAt: row.created_at.toISOString(),
    updatedAt: row.updated_at.toISOString(),
  };
}

function serializeRelationWithCounterpart(entry: TrainerRelationWithCounterpart) {
  return {
    ...serializeRelation(entry.relation),
    counterpart: entry.counterpart,
  };
}

function serializePlan(row: CoachNutritionPlanRow | null) {
  if (!row) return null;
  return {
    id: row.id,
    trainerId: row.trainer_id,
    title: row.title,
    calorieTarget: row.calorie_target,
    proteinTarget: row.protein_target,
    notes: row.notes,
    updatedAt: row.updated_at.toISOString(),
  };
}

function serializeAssignment(row: CoachMealAssignmentRow) {
  return {
    id: row.id,
    trainerId: row.trainer_id,
    recipeId: row.recipe_id,
    title: row.title,
    notes: row.notes,
    mealType: row.meal_type,
    createdAt: row.created_at.toISOString(),
  };
}

function serializeComment(row: CoachCommentRow) {
  return { id: row.id, trainerId: row.trainer_id, message: row.message, createdAt: row.created_at.toISOString() };
}

function serializeTargets(row: TargetsRow) {
  return {
    title: row.title,
    calorieGoal: row.calorie_goal,
    proteinGoal: row.protein_goal,
    fatGoal: row.fat_goal,
    carbsGoal: row.carbs_goal,
    waterGoalMl: row.water_goal_ml,
  };
}

export class TrainerController {
  constructor(private readonly service: TrainerService) {}

  becomeTrainer = asyncHandler(async (req, res) => {
    await this.service.becomeTrainer(req.userId as string);
    res.status(204).send();
  });

  inviteClient = asyncHandler(async (req, res) => {
    const body = req.validatedBody as InviteClientBody;
    const relation = await this.service.inviteClient(req.userId as string, body.email);
    res.status(201).json({ data: serializeRelation(relation) });
  });

  listMyClients = asyncHandler(async (req, res) => {
    const relations = await this.service.listMyClients(req.userId as string);
    res.status(200).json({ data: relations.map(serializeRelationWithCounterpart) });
  });

  listMyInvites = asyncHandler(async (req, res) => {
    const relations = await this.service.listMyInvites(req.userId as string);
    res.status(200).json({ data: relations.map(serializeRelationWithCounterpart) });
  });

  listMyTrainers = asyncHandler(async (req, res) => {
    const relations = await this.service.listMyTrainers(req.userId as string);
    res.status(200).json({ data: relations.map(serializeRelationWithCounterpart) });
  });

  respondToInvite = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as RelationIdParam;
    const body = req.validatedBody as RespondInviteBody;
    const relation = await this.service.respondToInvite(req.userId as string, id, body.approve);
    res.status(200).json({ data: serializeRelation(relation) });
  });

  revokeRelation = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as RelationIdParam;
    await this.service.revokeRelation(req.userId as string, id);
    res.status(204).send();
  });

  getClientDaily = asyncHandler(async (req, res) => {
    const { clientId } = req.validatedParams as ClientIdParam;
    const q = req.validatedQuery as ClientDateQuery;
    const summary = await this.service.getClientDaily(req.userId as string, clientId, q.date ?? today());
    res.status(200).json({ data: summary });
  });

  getClientAnalytics = asyncHandler(async (req, res) => {
    const { clientId } = req.validatedParams as ClientIdParam;
    const q = req.validatedQuery as ClientAnalyticsQuery;
    const result = await this.service.getClientAnalytics(req.userId as string, clientId, q.period);
    res.status(200).json({ data: result });
  });

  getClientGoals = asyncHandler(async (req, res) => {
    const { clientId } = req.validatedParams as ClientIdParam;
    const row = await this.service.getClientGoals(req.userId as string, clientId);
    res.status(200).json({ data: serializeTargets(row) });
  });

  setClientPlan = asyncHandler(async (req, res) => {
    const { clientId } = req.validatedParams as ClientIdParam;
    const body = req.validatedBody as SetCoachPlanBody;
    const row = await this.service.setClientPlan(req.userId as string, clientId, body);
    res.status(200).json({ data: serializePlan(row) });
  });

  assignMeal = asyncHandler(async (req, res) => {
    const { clientId } = req.validatedParams as ClientIdParam;
    const body = req.validatedBody as CreateAssignmentBody;
    const row = await this.service.assignMeal(req.userId as string, clientId, body);
    res.status(201).json({ data: serializeAssignment(row) });
  });

  removeAssignment = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as AssignmentIdParam;
    await this.service.removeAssignment(req.userId as string, id);
    res.status(204).send();
  });

  addComment = asyncHandler(async (req, res) => {
    const { clientId } = req.validatedParams as ClientIdParam;
    const body = req.validatedBody as CreateCommentBody;
    const row = await this.service.addComment(req.userId as string, clientId, body.message);
    res.status(201).json({ data: serializeComment(row) });
  });

  getMyCoachPlan = asyncHandler(async (req, res) => {
    const row = await this.service.getMyCoachPlan(req.userId as string);
    res.status(200).json({ data: serializePlan(row) });
  });

  getMyAssignments = asyncHandler(async (req, res) => {
    const rows = await this.service.getMyAssignments(req.userId as string);
    res.status(200).json({ data: rows.map(serializeAssignment) });
  });

  getMyComments = asyncHandler(async (req, res) => {
    const rows = await this.service.getMyComments(req.userId as string);
    res.status(200).json({ data: rows.map(serializeComment) });
  });
}
