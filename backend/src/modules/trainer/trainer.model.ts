import { MealType } from '../meal/meal.model';

export type TrainerClientStatus = 'pending' | 'approved' | 'declined' | 'revoked';

/** Минимум о другой стороне связи, чтобы Flutter мог показать не голый UUID, а имя/email. */
export interface PublicUserInfo {
  id: string;
  email: string;
  name: string;
}

export interface TrainerRelationWithCounterpart {
  relation: TrainerClientRow;
  counterpart: PublicUserInfo | null;
}

/** Связь тренер-клиент — ЕДИНСТВЕННЫЙ источник истины о том, кто кому может видеть данные (см. trainer.access.service.ts). */
export interface TrainerClientRow {
  id: string;
  trainer_id: string;
  client_id: string;
  status: TrainerClientStatus;
  share_photos: boolean;
  created_at: Date;
  updated_at: Date;
}

/** "Coach Plan" + "Daily Target", которые клиент видит у себя. */
export interface CoachNutritionPlanRow {
  id: string;
  client_id: string;
  trainer_id: string;
  title: string | null;
  calorie_target: number | null;
  protein_target: number | null;
  notes: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface CoachNutritionPlanPatch {
  title?: string | null;
  calorieTarget?: number | null;
  proteinTarget?: number | null;
  notes?: string | null;
}

/** "Assigned Meals" — либо назначенный рецепт (recipe_id), либо произвольный текстовый план. */
export interface CoachMealAssignmentRow {
  id: string;
  trainer_id: string;
  client_id: string;
  recipe_id: string | null;
  title: string;
  notes: string | null;
  meal_type: MealType | null;
  created_at: Date;
}

export interface CoachMealAssignmentInput {
  recipeId?: string | null;
  title: string;
  notes?: string | null;
  mealType?: MealType | null;
}

/** "Coach Comments" — рекомендации и комментарии тренера. */
export interface CoachCommentRow {
  id: string;
  trainer_id: string;
  client_id: string;
  message: string;
  created_at: Date;
}
