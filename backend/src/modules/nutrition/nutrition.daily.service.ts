import { MealService } from '../meal/meal.service';
import { NutritionCalculationService } from './nutrition.calculation.service';
import { NutritionTargetsRepository } from './nutrition.targets.repository';
import { NutritionWaterRepository } from './nutrition.water.repository';

export interface DailySummary {
  date: string;
  meals: Awaited<ReturnType<MealService['getDay']>>;
  consumed: {
    calories: number;
    protein: number;
    fat: number;
    carbohydrates: number;
  };
  targets: {
    title: string;
    calorieGoal: number;
    proteinGoal: number;
    fatGoal: number;
    carbsGoal: number;
    waterGoalMl: number;
  };
  remaining: {
    calories: number;
    protein: number;
    fat: number;
    carbohydrates: number;
  };
  progressPercent: number;
  water: {
    consumedMl: number;
    goalMl: number;
  };
}

/**
 * Собирает всё, что нужно для Nutrition Home Screen, одним запросом:
 * приёмы пищи с посчитанными нутриентами (MealService), цели
 * (NutritionTargetsRepository) и воду (NutritionWaterRepository).
 * "Съедено"/"Осталось"/"Прогресс" считаются здесь же (backend), чтобы
 * Flutter только показывал готовые числа.
 */
export class NutritionDailyService {
  constructor(
    private readonly meals: MealService,
    private readonly targets: NutritionTargetsRepository,
    private readonly water: NutritionWaterRepository,
    private readonly engine: NutritionCalculationService,
  ) {}

  async getDaily(userId: string, date: string): Promise<DailySummary> {
    const [mealsForDay, targetsRow, waterEntries] = await Promise.all([
      this.meals.getDay(userId, date),
      this.targets.getOrCreateDefault(userId),
      this.water.getForDate(userId, date),
    ]);

    const consumed = this.engine.sumProfiles(mealsForDay);
    const waterConsumedMl = waterEntries.reduce((sum, e) => sum + e.amount_ml, 0);

    return {
      date,
      meals: mealsForDay,
      consumed: {
        calories: consumed.calories,
        protein: consumed.protein,
        fat: consumed.fat,
        carbohydrates: consumed.carbohydrates,
      },
      targets: {
        title: targetsRow.title,
        calorieGoal: targetsRow.calorie_goal,
        proteinGoal: targetsRow.protein_goal,
        fatGoal: targetsRow.fat_goal,
        carbsGoal: targetsRow.carbs_goal,
        waterGoalMl: targetsRow.water_goal_ml,
      },
      remaining: {
        calories: targetsRow.calorie_goal - consumed.calories,
        protein: targetsRow.protein_goal - consumed.protein,
        fat: targetsRow.fat_goal - consumed.fat,
        carbohydrates: targetsRow.carbs_goal - consumed.carbohydrates,
      },
      progressPercent: targetsRow.calorie_goal === 0 ? 0 : Math.round((consumed.calories / targetsRow.calorie_goal) * 100),
      water: {
        consumedMl: waterConsumedMl,
        goalMl: targetsRow.water_goal_ml,
      },
    };
  }
}
