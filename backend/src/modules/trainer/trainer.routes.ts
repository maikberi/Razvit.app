import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { validate } from '../../middleware/validate';
import { AuthRepository } from '../auth/auth.repository';
import { RecipeRepository } from '../recipe/recipe.repository';
import { analyticsService, dailyService, targetsRepository } from '../nutrition/nutrition.routes';
import { TrainerAccessService } from './trainer.access.service';
import { TrainerController } from './trainer.controller';
import { TrainerRepository } from './trainer.repository';
import { TrainerService } from './trainer.service';
import {
  assignmentIdParamSchema,
  clientAnalyticsQuerySchema,
  clientDateQuerySchema,
  clientIdParamSchema,
  createAssignmentSchema,
  createCommentSchema,
  inviteClientSchema,
  relationIdParamSchema,
  respondInviteSchema,
  setCoachPlanSchema,
} from './trainer.validation';

const trainerRepository = new TrainerRepository(pool);
const accessService = new TrainerAccessService(trainerRepository);
const authRepository = new AuthRepository(pool);
const recipeRepository = new RecipeRepository(pool);
const service = new TrainerService(trainerRepository, accessService, authRepository, recipeRepository, dailyService, analyticsService, targetsRepository);
const controller = new TrainerController(service);

export const trainerRouter = Router();

// Стать тренером (курс, показывать вкладку "Мои клиенты" во Flutter) —
// не граница безопасности сама по себе, реальная проверка доступа всегда
// через approved-связь в trainer_clients (см. trainer.access.service.ts).
trainerRouter.post('/trainer/become', authUser, controller.becomeTrainer);

// Связь тренер-клиент.
trainerRouter.post('/trainer/clients/invite', authUser, validate(inviteClientSchema, 'body'), controller.inviteClient);
trainerRouter.get('/trainer/clients', authUser, controller.listMyClients);
trainerRouter.get('/trainer/invites', authUser, controller.listMyInvites);
trainerRouter.get('/trainer/my-trainers', authUser, controller.listMyTrainers);
trainerRouter.post(
  '/trainer/invites/:id/respond',
  authUser,
  validate(relationIdParamSchema, 'params'),
  validate(respondInviteSchema, 'body'),
  controller.respondToInvite,
);
trainerRouter.delete('/trainer/relations/:id', authUser, validate(relationIdParamSchema, 'params'), controller.revokeRelation);

// Тренер читает данные конкретного клиента — каждый метод сервиса сам
// проверяет approved-связь первым делом (см. TrainerService).
trainerRouter.get(
  '/trainer/clients/:clientId/daily',
  authUser,
  validate(clientIdParamSchema, 'params'),
  validate(clientDateQuerySchema, 'query'),
  controller.getClientDaily,
);
trainerRouter.get(
  '/trainer/clients/:clientId/analytics',
  authUser,
  validate(clientIdParamSchema, 'params'),
  validate(clientAnalyticsQuerySchema, 'query'),
  controller.getClientAnalytics,
);
trainerRouter.get('/trainer/clients/:clientId/goals', authUser, validate(clientIdParamSchema, 'params'), controller.getClientGoals);

// Тренер назначает клиенту.
trainerRouter.put(
  '/trainer/clients/:clientId/plan',
  authUser,
  validate(clientIdParamSchema, 'params'),
  validate(setCoachPlanSchema, 'body'),
  controller.setClientPlan,
);
trainerRouter.post(
  '/trainer/clients/:clientId/meal-assignments',
  authUser,
  validate(clientIdParamSchema, 'params'),
  validate(createAssignmentSchema, 'body'),
  controller.assignMeal,
);
trainerRouter.delete(
  '/trainer/meal-assignments/:id',
  authUser,
  validate(assignmentIdParamSchema, 'params'),
  controller.removeAssignment,
);
trainerRouter.post(
  '/trainer/clients/:clientId/comments',
  authUser,
  validate(clientIdParamSchema, 'params'),
  validate(createCommentSchema, 'body'),
  controller.addComment,
);

// Клиент читает СВОЁ (что назначил любой из его тренеров) — всегда req.userId, доступ не нужно проверять отдельно.
trainerRouter.get('/trainer/coach-plan', authUser, controller.getMyCoachPlan);
trainerRouter.get('/trainer/meal-assignments', authUser, controller.getMyAssignments);
trainerRouter.get('/trainer/coach-comments', authUser, controller.getMyComments);

export { TrainerController, TrainerRepository, TrainerService };
