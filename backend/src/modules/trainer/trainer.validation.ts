import { z } from 'zod';
import { MEAL_TYPES } from '../meal/meal.model';
import { ANALYTICS_PERIODS } from '../nutrition/nutritionAnalytics.model';

export const inviteClientSchema = z.object({
  email: z.string().trim().email('email must be valid'),
});

export const respondInviteSchema = z.object({
  approve: z.boolean(),
});

export const relationIdParamSchema = z.object({
  id: z.string().uuid('id must be a valid UUID'),
});

export const clientIdParamSchema = z.object({
  clientId: z.string().uuid('clientId must be a valid UUID'),
});

export const assignmentIdParamSchema = z.object({
  id: z.string().uuid('id must be a valid UUID'),
});

export const clientDateQuerySchema = z.object({
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD')
    .optional(),
});

export const clientAnalyticsQuerySchema = z.object({
  period: z.enum(ANALYTICS_PERIODS).default('30d'),
});

export const setCoachPlanSchema = z.object({
  title: z.string().trim().max(200).nullable().optional(),
  calorieTarget: z.number().int().min(0).nullable().optional(),
  proteinTarget: z.number().int().min(0).nullable().optional(),
  notes: z.string().trim().max(2000).nullable().optional(),
});

export const createAssignmentSchema = z.object({
  recipeId: z.string().uuid().optional(),
  title: z.string().trim().min(1, 'title is required').max(200),
  notes: z.string().trim().max(2000).nullable().optional(),
  mealType: z.enum(MEAL_TYPES).optional(),
});

export const createCommentSchema = z.object({
  message: z.string().trim().min(1, 'message is required').max(2000),
});

export type InviteClientBody = z.infer<typeof inviteClientSchema>;
export type RespondInviteBody = z.infer<typeof respondInviteSchema>;
export type RelationIdParam = z.infer<typeof relationIdParamSchema>;
export type ClientIdParam = z.infer<typeof clientIdParamSchema>;
export type AssignmentIdParam = z.infer<typeof assignmentIdParamSchema>;
export type ClientDateQuery = z.infer<typeof clientDateQuerySchema>;
export type ClientAnalyticsQuery = z.infer<typeof clientAnalyticsQuerySchema>;
export type SetCoachPlanBody = z.infer<typeof setCoachPlanSchema>;
export type CreateAssignmentBody = z.infer<typeof createAssignmentSchema>;
export type CreateCommentBody = z.infer<typeof createCommentSchema>;
