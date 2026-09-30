import { FoodRepository } from '../food/food.repository';
import { FoodRow } from '../food/food.model';
import { MealItemRow } from '../meal/meal.model';
import { MealRepository } from '../meal/meal.repository';
import { NutritionCalculationService, roundTo } from './nutrition.calculation.service';
import { FoodAmount, NutrientSource } from './nutrition.model';
import { NutritionTargetsRepository } from './nutrition.targets.repository';
import { NutritionWaterRepository } from './nutrition.water.repository';
import { AnalyticsPeriod, NutritionAnalyticsDay, NutritionAnalyticsResult } from './nutritionAnalytics.model';

const PERIOD_DAYS: Record<AnalyticsPeriod, number> = { '7d': 7, '30d': 30, '90d': 90 };

// Калории дня попадают "в цель", если укладываются в этот коридор вокруг
// calorieGoal — точное совпадение нереалистично требовать, ±10% это
// общепринятый ориентир "укладываешься в план".
const ON_TARGET_TOLERANCE = 0.1;

function dateRange(period: AnalyticsPeriod): { from: string; to: string; dates: string[] } {
  const days = PERIOD_DAYS[period];
  const today = new Date();
  const dates: string[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    dates.push(d.toISOString().slice(0, 10));
  }
  return { from: dates[0], to: dates[dates.length - 1], dates };
}

function toNutrientSource(row: MealItemRow, foodById: Map<string, FoodRow>): NutrientSource | null {
  if (row.food_id) {
    const food = foodById.get(row.food_id);
    if (!food) return null; // не должно происходить — foods нельзя удалить, пока есть ссылки
    return {
      calories: Number(food.calories),
      protein: Number(food.protein),
      fat: Number(food.fat),
      carbohydrates: Number(food.carbohydrates),
      fiber: Number(food.fiber),
      sugar: food.sugar != null ? Number(food.sugar) : null,
      sodium: food.sodium != null ? Number(food.sodium) : null,
    };
  }
  const n = row.custom_nutrients;
  if (!n) return null;
  return {
    calories: n.calories,
    protein: n.protein,
    fat: n.fat,
    carbohydrates: n.carbohydrates,
    fiber: n.fiber ?? 0,
    sugar: n.sugar ?? null,
    sodium: n.sodium ?? null,
  };
}

function average(values: number[], decimals: number): number {
  if (values.length === 0) return 0;
  return roundTo(values.reduce((sum, v) => sum + v, 0) / values.length, decimals);
}

/**
 * Nutrition Analytics — агрегированная статистика за период (7/30/90 дней),
 * вся математика на backend (Flutter только показывает готовые числа и не
 * получает тысячи сырых записей). Дневные суммы КБЖУ считает тот же
 * Nutrition Engine (NutritionCalculationService.forMeal), что и везде в
 * проекте — здесь только группировка по датам и усреднение уже готовых
 * дневных итогов (как NutritionCalculationService.forWeek делает для
 * dailyAverage), не повторный расчёт КБЖУ.
 */
export class NutritionAnalyticsService {
  constructor(
    private readonly meals: MealRepository,
    private readonly foods: FoodRepository,
    private readonly water: NutritionWaterRepository,
    private readonly targets: NutritionTargetsRepository,
    private readonly engine: NutritionCalculationService,
  ) {}

  async getAnalytics(userId: string, period: AnalyticsPeriod): Promise<NutritionAnalyticsResult> {
    const { from, to, dates } = dateRange(period);

    const [itemRows, waterRows, targetsRow] = await Promise.all([
      this.meals.getItemsForDateRange(userId, from, to),
      this.water.getRangeTotals(userId, from, to),
      this.targets.getOrCreateDefault(userId),
    ]);

    const foodIds = [...new Set(itemRows.filter((r) => r.food_id).map((r) => r.food_id as string))];
    const foodRows = await this.foods.findByIds(foodIds);
    const foodById = new Map(foodRows.map((f) => [f.id, f]));

    const amountsByDate = new Map<string, FoodAmount[]>();
    for (const row of itemRows) {
      const source = toNutrientSource(row, foodById);
      if (!source) continue;
      const list = amountsByDate.get(row.date) ?? [];
      list.push({ food: source, grams: Number(row.grams) });
      amountsByDate.set(row.date, list);
    }

    const waterByDate = new Map(waterRows.map((r) => [r.date, r.amount_ml]));
    const calorieGoal = targetsRow.calorie_goal;
    const tolerance = calorieGoal * ON_TARGET_TOLERANCE;

    const days: NutritionAnalyticsDay[] = dates.map((date) => {
      const amounts = amountsByDate.get(date) ?? [];
      const waterMl = waterByDate.get(date) ?? 0;
      const hasEntries = amounts.length > 0 || waterMl > 0;
      const profile = this.engine.forMeal(amounts);
      const onTarget = amounts.length > 0 && Math.abs(profile.calories - calorieGoal) <= tolerance;
      return {
        date,
        calories: profile.calories,
        protein: profile.protein,
        fat: profile.fat,
        carbohydrates: profile.carbohydrates,
        waterMl,
        hasEntries,
        onTarget,
      };
    });

    const loggedDays = days.filter((d) => d.hasEntries);
    const daysOnTarget = days.filter((d) => d.onTarget).length;

    return {
      period,
      from,
      to,
      days,
      averages: {
        calories: average(loggedDays.map((d) => d.calories), 0),
        protein: average(loggedDays.map((d) => d.protein), 1),
        fat: average(loggedDays.map((d) => d.fat), 1),
        carbohydrates: average(loggedDays.map((d) => d.carbohydrates), 1),
        waterMl: average(loggedDays.map((d) => d.waterMl), 0),
      },
      goalAdherencePercent: loggedDays.length ? Math.round((daysOnTarget / loggedDays.length) * 100) : 0,
      daysOnTarget,
      loggedDays: loggedDays.length,
      totalDays: dates.length,
      targets: {
        calorieGoal: targetsRow.calorie_goal,
        proteinGoal: targetsRow.protein_goal,
        fatGoal: targetsRow.fat_goal,
        carbsGoal: targetsRow.carbs_goal,
        waterGoalMl: targetsRow.water_goal_ml,
      },
    };
  }
}
