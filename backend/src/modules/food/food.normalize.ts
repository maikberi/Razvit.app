/**
 * Нормализация названия — для поиска и дедупликации.
 * Убираем регистр, лишние пробелы, пунктуацию и диакритику
 * (чтобы "Гречка", "гречка!", "Grechka" по-разному написанные
 * варианты одного слова сравнивались одинаково).
 */
export function normalizeName(raw: string): string {
  return raw
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '') // диакритика
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ') // пунктуация -> пробел
    .replace(/\s+/g, ' ')
    .trim();
}

export type BasisUnit = 'g' | 'ml';

export interface RawNutrients {
  calories: number;
  protein: number;
  fat: number;
  carbohydrates: number;
  fiber?: number;
  sugar?: number | null;
  sodium?: number | null;
}

/**
 * Приводит нутриенты, указанные для произвольного количества (например,
 * "на порцию 30 г" или "на 1 чашку (240 мл)"), к стандартному базису —
 * на 100 г или на 100 мл, как того требует Nutrition Module.
 *
 * Сама исходная порция (amount/unit) отдельно сохраняется как
 * serving_size/serving_unit — здесь не теряется, просто не участвует
 * в расчёте нормализованных значений.
 */
export function normalizeToPer100(nutrients: RawNutrients, forAmount: number, basisUnit: BasisUnit): RawNutrients {
  if (forAmount <= 0) {
    throw new Error('forAmount must be > 0 to normalize nutrients');
  }
  if (forAmount === 100) {
    return { ...nutrients, fiber: nutrients.fiber ?? 0 };
  }
  const ratio = 100 / forAmount;
  const round = (n: number) => Math.round(n * 100) / 100;
  return {
    calories: round(nutrients.calories * ratio),
    protein: round(nutrients.protein * ratio),
    fat: round(nutrients.fat * ratio),
    carbohydrates: round(nutrients.carbohydrates * ratio),
    fiber: round((nutrients.fiber ?? 0) * ratio),
    sugar: nutrients.sugar == null ? null : round(nutrients.sugar * ratio),
    sodium: nutrients.sodium == null ? null : round(nutrients.sodium * ratio),
  };
}
