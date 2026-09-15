import { ActivityLevel, CompleteNutritionProfile, NutritionGoal, NutritionProfileRow } from './nutritionProfile.model';

/** Профиль неполный — не хватает полей, перечисленных в missingFields, чтобы посчитать цели. */
export class IncompleteNutritionProfileError extends Error {
  constructor(public readonly missingFields: string[]) {
    super(`Nutrition profile is incomplete: missing ${missingFields.join(', ')}`);
    this.name = 'IncompleteNutritionProfileError';
  }
}

export interface NutritionTargetsResult {
  calorieGoal: number;
  proteinGoal: number;
  fatGoal: number;
  carbsGoal: number;
  waterGoalMl: number;
}

// Множитель TDEE = BMR * activityMultiplier (классическая 5-ступенчатая
// шкала Харриса-Бенедикта/Mifflin-St Jeor).
const ACTIVITY_MULTIPLIER: Record<ActivityLevel, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  very_active: 1.9,
};

// На сколько (доля от TDEE) корректируем калории под цель пользователя, и
// сколько белка (г на кг веса) закладываем — сохранение мышц при дефиците
// и рост мышц при профиците требуют больше белка, чем просто поддержание.
const GOAL_ADJUSTMENT: Record<NutritionGoal, { calorieDelta: number; proteinPerKg: number }> = {
  lose_weight: { calorieDelta: -0.2, proteinPerKg: 2.0 },
  gain_muscle: { calorieDelta: 0.1, proteinPerKg: 2.0 },
  get_stronger: { calorieDelta: 0.05, proteinPerKg: 1.8 },
  improve_shape: { calorieDelta: -0.1, proteinPerKg: 1.8 },
  endurance: { calorieDelta: 0.05, proteinPerKg: 1.6 },
  maintain: { calorieDelta: 0, proteinPerKg: 1.6 },
};

// Безопасный минимум калорий — резкий дефицит ниже этого небезопасен
// независимо от того, что говорит формула (общепринятые ориентиры).
const MIN_CALORIES_MALE = 1500;
const MIN_CALORIES_FEMALE = 1200;

// Жиры — фиксированная доля калорий (в общепринятом диапазоне 20-35%),
// углеводы — весь остаток. И жиры, и углеводы никогда не дают отрицательные
// граммы: если после белка почти не осталось калорий (очень низкий вес +
// большой дефицит), сначала подрезаем жир, а не уходим в минус.
const FAT_SHARE_OF_CALORIES = 0.25;
const MIN_FAT_GRAMS_PER_KG = 0.5; // ниже этого — риск дефицита незаменимых жирных кислот

const WATER_ML_PER_KG = 33;
const WATER_ACTIVITY_BONUS_ML = 300; // за каждую ступень активности выше sedentary
const MIN_WATER_ML = 1500;
const MAX_WATER_ML = 5000;

const REQUIRED_FIELDS: Array<[keyof CompleteNutritionProfile, string]> = [
  ['sex', 'sex'],
  ['age', 'age'],
  ['heightCm', 'heightCm'],
  ['weightKg', 'weightKg'],
  ['activityLevel', 'activityLevel'],
  ['goal', 'goal'],
];

/**
 * Nutrition Target Service — ОТДЕЛЬНЫЙ от Nutrition Engine
 * (NutritionCalculationService) сервис: тот считает КБЖУ уже съеденной еды
 * из данных продуктов, а этот — персональные ЦЕЛИ по КБЖУ и воде из
 * профиля пользователя. Ничего общего в данных или ответственности, кроме
 * так же единственного места, где считается конкретная математика.
 *
 * Pipeline: User Profile -> BMR/TDEE calculation -> Goal adjustment ->
 * Calories -> Macros (+ Water).
 */
export class NutritionTargetService {
  missingFields(row: NutritionProfileRow | null): string[] {
    const profile: Partial<CompleteNutritionProfile> = row
      ? {
          sex: row.sex ?? undefined,
          age: row.age ?? undefined,
          heightCm: row.height_cm != null ? Number(row.height_cm) : undefined,
          weightKg: row.weight_kg != null ? Number(row.weight_kg) : undefined,
          activityLevel: row.activity_level ?? undefined,
          goal: row.goal ?? undefined,
        }
      : {};
    return REQUIRED_FIELDS.filter(([key]) => profile[key] == null).map(([, name]) => name);
  }

  toCompleteProfile(row: NutritionProfileRow | null): CompleteNutritionProfile {
    const missing = this.missingFields(row);
    if (missing.length > 0) throw new IncompleteNutritionProfileError(missing);
    return {
      sex: row!.sex!,
      age: row!.age!,
      heightCm: Number(row!.height_cm),
      weightKg: Number(row!.weight_kg),
      activityLevel: row!.activity_level!,
      goal: row!.goal!,
    };
  }

  /** BMR (Mifflin-St Jeor) -> TDEE -> Goal adjustment -> Calories -> Macros. */
  computeTargets(profile: CompleteNutritionProfile): NutritionTargetsResult {
    const bmr = this.calculateBmr(profile);
    const tdee = bmr * ACTIVITY_MULTIPLIER[profile.activityLevel];

    const { calorieDelta, proteinPerKg } = GOAL_ADJUSTMENT[profile.goal];
    const minCalories = profile.sex === 'male' ? MIN_CALORIES_MALE : MIN_CALORIES_FEMALE;
    const calorieGoal = Math.max(minCalories, Math.round(tdee * (1 + calorieDelta)));

    const proteinGoal = Math.round(profile.weightKg * proteinPerKg);
    const proteinCalories = proteinGoal * 4;

    const minFatGoal = Math.round(profile.weightKg * MIN_FAT_GRAMS_PER_KG);
    const targetFatGoal = Math.round((calorieGoal * FAT_SHARE_OF_CALORIES) / 9);
    const fatGoal = Math.max(minFatGoal, targetFatGoal);
    const fatCalories = fatGoal * 9;

    const remainingCalories = calorieGoal - proteinCalories - fatCalories;
    const carbsGoal = Math.max(0, Math.round(remainingCalories / 4));

    const activityIndex = Object.keys(ACTIVITY_MULTIPLIER).indexOf(profile.activityLevel);
    const waterGoalMl = Math.min(
      MAX_WATER_ML,
      Math.max(MIN_WATER_ML, Math.round(profile.weightKg * WATER_ML_PER_KG + activityIndex * WATER_ACTIVITY_BONUS_ML)),
    );

    return { calorieGoal, proteinGoal, fatGoal, carbsGoal, waterGoalMl };
  }

  private calculateBmr(profile: CompleteNutritionProfile): number {
    const base = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * profile.age;
    return profile.sex === 'male' ? base + 5 : base - 161;
  }
}
