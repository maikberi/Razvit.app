import { FoodAmount, MicronutrientMap, NutrientProfile, NutrientSource } from './nutrition.model';

/**
 * Правила округления результата. Считаем ВСЕГДА с полной точностью
 * (double) и округляем только один раз, в самом конце — иначе при
 * суммировании многих продуктов (Meal/Day/Week) накопится ошибка
 * округления. Это единственное место, где эти числа заданы —
 * меняется здесь, а не в десяти местах по коду.
 */
export const ROUNDING = {
  calories: 0,
  protein: 1,
  fat: 1,
  carbohydrates: 1,
  fiber: 1,
  sugar: 1,
  sodium: 0,
  micronutrient: 2,
} as const;

/** Внутреннее (неокруглённое) представление — используется только для сложения. */
interface RawProfile {
  calories: number;
  protein: number;
  fat: number;
  carbohydrates: number;
  fiber: number;
  sugar: number | null;
  sugarKnown: boolean; // хотя бы один вклад имел не-null значение
  sodium: number | null;
  sodiumKnown: boolean;
  micronutrients: Record<string, { amount: number; unit: string }>;
}

function emptyRaw(): RawProfile {
  return {
    calories: 0,
    protein: 0,
    fat: 0,
    carbohydrates: 0,
    fiber: 0,
    sugar: 0,
    sugarKnown: false,
    sodium: 0,
    sodiumKnown: false,
    micronutrients: {},
  };
}

/**
 * Математически корректное округление до N знаков (без проблем плавающей
 * точки вроде 1.005 -> 1.00). Детерминировано: одинаковый вход всегда
 * даёт одинаковый выход.
 */
export function roundTo(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round((value + Number.EPSILON) * factor) / factor;
}

function round(raw: RawProfile): NutrientProfile {
  const micronutrients: MicronutrientMap = {};
  for (const [key, { amount, unit }] of Object.entries(raw.micronutrients)) {
    micronutrients[key] = { amount: roundTo(amount, ROUNDING.micronutrient), unit };
  }
  return {
    calories: roundTo(raw.calories, ROUNDING.calories),
    protein: roundTo(raw.protein, ROUNDING.protein),
    fat: roundTo(raw.fat, ROUNDING.fat),
    carbohydrates: roundTo(raw.carbohydrates, ROUNDING.carbohydrates),
    fiber: roundTo(raw.fiber, ROUNDING.fiber),
    sugar: raw.sugarKnown ? roundTo(raw.sugar as number, ROUNDING.sugar) : null,
    sodium: raw.sodiumKnown ? roundTo(raw.sodium as number, ROUNDING.sodium) : null,
    micronutrients,
  };
}

/**
 * NutritionCalculationService — единственное место во всём проекте,
 * где считаются итоговые калории/БЖУ. Никакой другой код (ни backend,
 * ни тем более Flutter) не должен сам умножать/делить нутриенты — только
 * вызывать этот сервис. Никакой БД, никакого состояния — чистые функции,
 * поэтому результат всегда детерминирован и легко тестируется.
 */
export class NutritionCalculationService {
  /** Продукт в количестве `grams` граммов: value * grams / 100 для каждого поля. */
  private scaleToRaw(food: NutrientSource, grams: number): RawProfile {
    const ratio = grams / 100;
    const raw = emptyRaw();
    raw.calories = food.calories * ratio;
    raw.protein = food.protein * ratio;
    raw.fat = food.fat * ratio;
    raw.carbohydrates = food.carbohydrates * ratio;
    raw.fiber = food.fiber * ratio;
    if (food.sugar != null) {
      raw.sugar = food.sugar * ratio;
      raw.sugarKnown = true;
    } else {
      raw.sugar = 0;
      raw.sugarKnown = false;
    }
    if (food.sodium != null) {
      raw.sodium = food.sodium * ratio;
      raw.sodiumKnown = true;
    } else {
      raw.sodium = 0;
      raw.sodiumKnown = false;
    }
    for (const [key, { amount, unit }] of Object.entries(food.micronutrients ?? {})) {
      raw.micronutrients[key] = { amount: amount * ratio, unit };
    }
    return raw;
  }

  /** Food: продукт в конкретном количестве граммов (100 г / 250 г / 500 г / любое). */
  forFoodAmount(food: NutrientSource, grams: number): NutrientProfile {
    return round(this.scaleToRaw(food, grams));
  }

  private sumRaw(items: FoodAmount[]): RawProfile {
    const total = emptyRaw();
    for (const { food, grams } of items) {
      const raw = this.scaleToRaw(food, grams);
      total.calories += raw.calories;
      total.protein += raw.protein;
      total.fat += raw.fat;
      total.carbohydrates += raw.carbohydrates;
      total.fiber += raw.fiber;
      if (raw.sugarKnown) {
        total.sugar = (total.sugar ?? 0) + raw.sugar!;
        total.sugarKnown = true;
      }
      if (raw.sodiumKnown) {
        total.sodium = (total.sodium ?? 0) + raw.sodium!;
        total.sodiumKnown = true;
      }
      for (const [key, { amount, unit }] of Object.entries(raw.micronutrients)) {
        const existing = total.micronutrients[key];
        total.micronutrients[key] = { amount: (existing?.amount ?? 0) + amount, unit };
      }
    }
    return total;
  }

  /** Meal: сумма нескольких продуктов в рамках одного приёма пищи. */
  forMeal(items: FoodAmount[]): NutrientProfile {
    return round(this.sumRaw(items));
  }

  /**
   * Recipe: сумма ингредиентов = общее блюдо (total), плюс расчёт на одну
   * порцию (perServing = total / servings, из НЕокруглённой суммы, чтобы
   * не терять точность при делении уже округлённого числа).
   */
  forRecipe(items: FoodAmount[], servings = 1): { total: NutrientProfile; perServing: NutrientProfile } {
    if (servings <= 0) {
      throw new Error('servings must be a positive number');
    }
    const raw = this.sumRaw(items);
    const total = round(raw);
    const perServingRaw: RawProfile = {
      calories: raw.calories / servings,
      protein: raw.protein / servings,
      fat: raw.fat / servings,
      carbohydrates: raw.carbohydrates / servings,
      fiber: raw.fiber / servings,
      sugar: raw.sugarKnown ? (raw.sugar as number) / servings : 0,
      sugarKnown: raw.sugarKnown,
      sodium: raw.sodiumKnown ? (raw.sodium as number) / servings : 0,
      sodiumKnown: raw.sodiumKnown,
      micronutrients: Object.fromEntries(
        Object.entries(raw.micronutrients).map(([key, { amount, unit }]) => [key, { amount: amount / servings, unit }]),
      ),
    };
    return { total, perServing: round(perServingRaw) };
  }

  /**
   * Day: все приёмы пищи за день. Каждый meal — список продуктов; суммируем
   * все продукты всех приёмов пищи по полной точности (не через уже
   * округлённые итоги отдельных meal, чтобы избежать накопления ошибки).
   */
  forDay(meals: FoodAmount[][]): NutrientProfile {
    return round(this.sumRaw(meals.flat()));
  }

  private accumulate(profiles: NutrientProfile[]): RawProfile {
    const raw = emptyRaw();
    for (const p of profiles) {
      raw.calories += p.calories;
      raw.protein += p.protein;
      raw.fat += p.fat;
      raw.carbohydrates += p.carbohydrates;
      raw.fiber += p.fiber;
      if (p.sugar != null) {
        raw.sugar = (raw.sugar ?? 0) + p.sugar;
        raw.sugarKnown = true;
      }
      if (p.sodium != null) {
        raw.sodium = (raw.sodium ?? 0) + p.sodium;
        raw.sodiumKnown = true;
      }
      for (const [key, { amount, unit }] of Object.entries(p.micronutrients)) {
        const existing = raw.micronutrients[key];
        raw.micronutrients[key] = { amount: (existing?.amount ?? 0) + amount, unit };
      }
    }
    return raw;
  }

  /**
   * Складывает несколько уже посчитанных NutrientProfile (например, итоги
   * приёмов пищи -> итог за день). В отличие от forMeal/forFoodAmount,
   * НЕ масштабирует по граммам — просто точная сумма готовых значений.
   */
  sumProfiles(profiles: NutrientProfile[]): NutrientProfile {
    return round(this.accumulate(profiles));
  }

  /**
   * Week: агрегированная статистика по уже посчитанным дневным итогам
   * (например, взятым из истории питания) — суммарно за неделю и
   * среднее в день.
   */
  forWeek(dailyTotals: NutrientProfile[]): { total: NutrientProfile; dailyAverage: NutrientProfile } {
    if (dailyTotals.length === 0) {
      const zero = round(emptyRaw());
      return { total: zero, dailyAverage: zero };
    }
    const raw = this.accumulate(dailyTotals);
    const n = dailyTotals.length;
    const total = round(raw);
    const averageRaw: RawProfile = {
      calories: raw.calories / n,
      protein: raw.protein / n,
      fat: raw.fat / n,
      carbohydrates: raw.carbohydrates / n,
      fiber: raw.fiber / n,
      sugar: raw.sugarKnown ? (raw.sugar as number) / n : 0,
      sugarKnown: raw.sugarKnown,
      sodium: raw.sodiumKnown ? (raw.sodium as number) / n : 0,
      sodiumKnown: raw.sodiumKnown,
      micronutrients: Object.fromEntries(
        Object.entries(raw.micronutrients).map(([key, { amount, unit }]) => [key, { amount: amount / n, unit }]),
      ),
    };
    return { total, dailyAverage: round(averageRaw) };
  }
}
