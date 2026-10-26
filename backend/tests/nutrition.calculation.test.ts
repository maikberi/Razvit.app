import { NutritionCalculationService, roundTo } from '../src/modules/nutrition/nutrition.calculation.service';
import { NutrientSource } from '../src/modules/nutrition/nutrition.model';

const engine = new NutritionCalculationService();

const chicken: NutrientSource = {
  calories: 165,
  protein: 31,
  fat: 3.6,
  carbohydrates: 0,
  fiber: 0,
  sugar: 0,
  sodium: 74,
};

describe('NutritionCalculationService.forFoodAmount', () => {
  it('пример из ТЗ: курица 100г=165ккал, 200г -> 330 ккал, белок 31*2=62', () => {
    const result = engine.forFoodAmount(chicken, 200);
    expect(result.calories).toBe(330);
    expect(result.protein).toBe(62);
    expect(result.fat).toBe(7.2);
    expect(result.sodium).toBe(148);
  });

  it('0 г -> всё по нулям (кроме sugar/sodium, если продукт их не содержит)', () => {
    const result = engine.forFoodAmount(chicken, 0);
    expect(result.calories).toBe(0);
    expect(result.protein).toBe(0);
    expect(result.fat).toBe(0);
    expect(result.carbohydrates).toBe(0);
    expect(result.fiber).toBe(0);
    expect(result.sugar).toBe(0); // у курицы sugar=0 (известно, что 0), а не null
    expect(result.sodium).toBe(0);
  });

  it('null-поля (неизвестный sugar/sodium) остаются null при любом количестве, включая 0', () => {
    const unknown: NutrientSource = { ...chicken, sugar: null, sodium: null };
    expect(engine.forFoodAmount(unknown, 0).sugar).toBeNull();
    expect(engine.forFoodAmount(unknown, 100).sugar).toBeNull();
    expect(engine.forFoodAmount(unknown, 250).sodium).toBeNull();
  });

  it('1 г -> пропорционально', () => {
    const result = engine.forFoodAmount(chicken, 1);
    expect(result.calories).toBe(roundTo(165 / 100, 0));
    expect(result.protein).toBe(roundTo(31 / 100, 1));
  });

  it('100 г -> ровно исходные значения на 100 г', () => {
    const result = engine.forFoodAmount(chicken, 100);
    expect(result.calories).toBe(165);
    expect(result.protein).toBe(31);
    expect(result.fat).toBe(3.6);
    expect(result.sodium).toBe(74);
  });

  it('250 г -> ×2.5', () => {
    const result = engine.forFoodAmount(chicken, 250);
    expect(result.calories).toBe(413); // 412.5 -> округление до целого
    expect(result.protein).toBe(77.5);
    expect(result.fat).toBe(9);
  });

  it('500 г -> ×5', () => {
    const result = engine.forFoodAmount(chicken, 500);
    expect(result.calories).toBe(825);
    expect(result.protein).toBe(155);
    expect(result.fat).toBe(18);
    expect(result.sodium).toBe(370);
  });

  it('дробные граммы (137.5 г) считаются точно, округляются только на выходе', () => {
    const result = engine.forFoodAmount(chicken, 137.5);
    expect(result.calories).toBe(roundTo((165 * 137.5) / 100, 0));
    expect(result.protein).toBe(roundTo((31 * 137.5) / 100, 1));
  });

  it('дробные нутриенты продукта (например, 4.2 г белка на 100 г)', () => {
    const oats: NutrientSource = { calories: 110, protein: 3.6, fat: 2, carbohydrates: 19, fiber: 1.7, sugar: 0.8, sodium: 12 };
    const result = engine.forFoodAmount(oats, 250);
    expect(result.protein).toBe(9); // 3.6*2.5=9
    expect(result.fiber).toBe(4.3); // 1.7*2.5=4.25 -> округление до 1 знака = 4.3 (round half up)
  });

  it('очень большие значения не ломают расчёт (нет NaN/Infinity)', () => {
    const dense: NutrientSource = { calories: 900, protein: 0, fat: 100, carbohydrates: 0, fiber: 0, sugar: 0, sodium: 0 };
    const result = engine.forFoodAmount(dense, 1_000_000); // 1000 кг
    expect(result.calories).toBe(9_000_000);
    expect(result.fat).toBe(1_000_000);
    expect(Number.isFinite(result.calories)).toBe(true);
  });

  it('переносит микронутриенты, масштабируя их вместе с остальным', () => {
    const spinach: NutrientSource = {
      calories: 23,
      protein: 2.9,
      fat: 0.4,
      carbohydrates: 3.6,
      fiber: 2.2,
      sugar: 0.4,
      sodium: 79,
      micronutrients: { iron: { amount: 2.7, unit: 'mg' }, vitamin_c: { amount: 28, unit: 'mg' } },
    };
    const result = engine.forFoodAmount(spinach, 200);
    expect(result.micronutrients.iron).toEqual({ amount: 5.4, unit: 'mg' });
    expect(result.micronutrients.vitamin_c).toEqual({ amount: 56, unit: 'mg' });
  });
});

describe('NutritionCalculationService.forMeal (несколько продуктов)', () => {
  const rice: NutrientSource = { calories: 112, protein: 2.6, fat: 0.9, carbohydrates: 23, fiber: 1.8, sugar: 0, sodium: 5 };
  const oil: NutrientSource = { calories: 884, protein: 0, fat: 100, carbohydrates: 0, fiber: 0, sugar: null, sodium: null };

  it('суммирует несколько продуктов', () => {
    const result = engine.forMeal([
      { food: chicken, grams: 150 },
      { food: rice, grams: 100 },
      { food: oil, grams: 10 },
    ]);
    // 165*1.5=247.5 + 112 + 884*0.1=88.4 = 447.9 -> round 448
    expect(result.calories).toBe(448);
    // 31*1.5=46.5 + 2.6 + 0 = 49.1
    expect(result.protein).toBe(49.1);
  });

  it('если один продукт не знает sugar/sodium, а другой знает — сумма берёт известное (null не обнуляет всё)', () => {
    const result = engine.forMeal([
      { food: chicken, grams: 100 }, // sodium известен: 74
      { food: oil, grams: 10 }, // sodium неизвестен: null
    ]);
    expect(result.sodium).toBe(74); // вклад oil просто не учтён, а не занулил итог
  });

  it('если у ВСЕХ продуктов поле неизвестно — итог null, а не 0', () => {
    const unknownA: NutrientSource = { ...oil, sugar: null };
    const unknownB: NutrientSource = { ...oil, sugar: null };
    const result = engine.forMeal([
      { food: unknownA, grams: 50 },
      { food: unknownB, grams: 50 },
    ]);
    expect(result.sugar).toBeNull();
  });

  it('пустой список продуктов -> все нули', () => {
    const result = engine.forMeal([]);
    expect(result.calories).toBe(0);
    expect(result.protein).toBe(0);
  });

  it('суммирует и объединяет микронутриенты из разных продуктов', () => {
    const a: NutrientSource = { calories: 10, protein: 0, fat: 0, carbohydrates: 0, fiber: 0, sugar: 0, sodium: 0, micronutrients: { iron: { amount: 1, unit: 'mg' } } };
    const b: NutrientSource = { calories: 10, protein: 0, fat: 0, carbohydrates: 0, fiber: 0, sugar: 0, sodium: 0, micronutrients: { iron: { amount: 2, unit: 'mg' }, calcium: { amount: 5, unit: 'mg' } } };
    const result = engine.forMeal([
      { food: a, grams: 100 },
      { food: b, grams: 100 },
    ]);
    expect(result.micronutrients.iron).toEqual({ amount: 3, unit: 'mg' });
    expect(result.micronutrients.calcium).toEqual({ amount: 5, unit: 'mg' });
  });
});

describe('NutritionCalculationService.forRecipe', () => {
  const dough: NutrientSource = { calories: 265, protein: 9, fat: 3.2, carbohydrates: 49, fiber: 2.3, sugar: 2, sodium: 490 };
  const cheese: NutrientSource = { calories: 402, protein: 25, fat: 33, carbohydrates: 1.3, fiber: 0, sugar: 0.5, sodium: 621 };

  it('считает общее блюдо (total) как сумму ингредиентов', () => {
    const { total } = engine.forRecipe([
      { food: dough, grams: 300 },
      { food: cheese, grams: 200 },
    ]);
    // 265*3=795 + 402*2=804 = 1599
    expect(total.calories).toBe(1599);
  });

  it('делит на порции (perServing) без потери точности от округления total', () => {
    const { total, perServing } = engine.forRecipe(
      [
        { food: dough, grams: 300 },
        { food: cheese, grams: 200 },
      ],
      4,
    );
    expect(total.calories).toBe(1599);
    expect(perServing.calories).toBe(roundTo(1599 / 4, 0)); // 399.75 -> 400
  });

  it('servings по умолчанию = 1 -> perServing равен total', () => {
    const { total, perServing } = engine.forRecipe([{ food: dough, grams: 300 }]);
    expect(perServing).toEqual(total);
  });

  it('бросает ошибку при servings <= 0', () => {
    expect(() => engine.forRecipe([{ food: dough, grams: 300 }], 0)).toThrow();
    expect(() => engine.forRecipe([{ food: dough, grams: 300 }], -2)).toThrow();
  });
});

describe('NutritionCalculationService.forDay', () => {
  const oats: NutrientSource = { calories: 110, protein: 3.6, fat: 2, carbohydrates: 19, fiber: 1.7, sugar: 0.8, sodium: 12 };
  const chickenBreast = chicken;

  it('суммирует все приёмы пищи за день без промежуточного округления', () => {
    const result = engine.forDay([
      [{ food: oats, grams: 250 }], // завтрак
      [{ food: chickenBreast, grams: 150 }], // обед
    ]);
    // 110*2.5=275 + 165*1.5=247.5 = 522.5 -> round 523 (round half up)
    expect(result.calories).toBe(523);
  });

  it('день без приёмов пищи (пустой массив meals не проходит по схеме API, но сам движок отдаёт нули)', () => {
    const result = engine.forDay([]);
    expect(result.calories).toBe(0);
  });
});

describe('NutritionCalculationService.forWeek', () => {
  it('считает сумму и среднее за несколько дней', () => {
    const day1 = engine.forFoodAmount(chicken, 300); // 495 ккал
    const day2 = engine.forFoodAmount(chicken, 100); // 165 ккал
    const { total, dailyAverage } = engine.forWeek([day1, day2]);
    expect(total.calories).toBe(660);
    expect(dailyAverage.calories).toBe(330);
  });

  it('пустая неделя -> нули, без деления на 0', () => {
    const { total, dailyAverage } = engine.forWeek([]);
    expect(total.calories).toBe(0);
    expect(dailyAverage.calories).toBe(0);
  });

  it('среднее считается по неокруглённой сумме (не среднее округлённых)', () => {
    // 3 дня по 100г курицы -> calories по 165 каждый день (уже округлено на forFoodAmount)
    const day = engine.forFoodAmount(chicken, 100);
    const { dailyAverage } = engine.forWeek([day, day, day]);
    expect(dailyAverage.calories).toBe(165);
  });
});

describe('Округление — детерминированность', () => {
  it('одинаковый вход всегда даёт одинаковый результат', () => {
    const a = engine.forFoodAmount(chicken, 137.3);
    const b = engine.forFoodAmount(chicken, 137.3);
    expect(a).toEqual(b);
  });

  it('roundTo корректно округляет "половинки" (round half up), без ошибок плавающей точки', () => {
    expect(roundTo(1.005, 2)).toBe(1.01);
    expect(roundTo(4.25, 1)).toBe(4.3);
    expect(roundTo(0.5, 0)).toBe(1);
    expect(roundTo(412.5, 0)).toBe(413);
  });
});
