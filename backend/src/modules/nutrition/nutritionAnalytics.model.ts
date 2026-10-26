export const ANALYTICS_PERIODS = ['7d', '30d', '90d'] as const;
export type AnalyticsPeriod = (typeof ANALYTICS_PERIODS)[number];

export interface NutritionAnalyticsDay {
  date: string;
  calories: number;
  protein: number;
  fat: number;
  carbohydrates: number;
  waterMl: number;
  /** Хоть что-то залогировано в этот день (продукт или вода) — дни без записей не считаются ни в среднее, ни в goal adherence. */
  hasEntries: boolean;
  /** Калории в этот день попали в допустимый коридор вокруг calorieGoal (см. ON_TARGET_TOLERANCE). */
  onTarget: boolean;
}

export interface NutritionAnalyticsAverages {
  calories: number;
  protein: number;
  fat: number;
  carbohydrates: number;
  waterMl: number;
}

export interface NutritionAnalyticsResult {
  period: AnalyticsPeriod;
  from: string;
  to: string;
  days: NutritionAnalyticsDay[];
  averages: NutritionAnalyticsAverages;
  /** % дней с записями, попавших в цель по калориям. */
  goalAdherencePercent: number;
  daysOnTarget: number;
  /** Сколько дней из периода реально велись записи (знаменатель для goalAdherencePercent). */
  loggedDays: number;
  /** Длина периода целиком (7/30/90), для контекста в UI ("залогировано X из Y дней"). */
  totalDays: number;
  targets: {
    calorieGoal: number;
    proteinGoal: number;
    fatGoal: number;
    carbsGoal: number;
    waterGoalMl: number;
  };
}
