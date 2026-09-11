import { asyncHandler } from '../../utils/asyncHandler';
import { NutritionDailyService } from './nutrition.daily.service';
import { NutritionTargetsRepository } from './nutrition.targets.repository';
import { NutritionWaterRepository } from './nutrition.water.repository';
import { AddWaterBody, DateQuery, UpdateTargetsBody } from './nutrition.validation';

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function serializeTargets(row: Awaited<ReturnType<NutritionTargetsRepository['getOrCreateDefault']>>) {
  return {
    title: row.title,
    calorieGoal: row.calorie_goal,
    proteinGoal: row.protein_goal,
    fatGoal: row.fat_goal,
    carbsGoal: row.carbs_goal,
    waterGoalMl: row.water_goal_ml,
  };
}

/** Nutrition Home Screen: дневная сводка, цели, вода — то, что нужно per-пользователю. */
export class NutritionDailyController {
  constructor(
    private readonly daily: NutritionDailyService,
    private readonly targets: NutritionTargetsRepository,
    private readonly water: NutritionWaterRepository,
  ) {}

  /** GET /nutrition/daily?date= — всё для Nutrition Home Screen одним запросом. */
  getDaily = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as DateQuery;
    const summary = await this.daily.getDaily(req.userId as string, q.date ?? today());
    res.status(200).json({ data: summary });
  });

  getTargets = asyncHandler(async (req, res) => {
    const row = await this.targets.getOrCreateDefault(req.userId as string);
    res.status(200).json({ data: serializeTargets(row) });
  });

  updateTargets = asyncHandler(async (req, res) => {
    const body = req.validatedBody as UpdateTargetsBody;
    const row = await this.targets.upsert(req.userId as string, body);
    res.status(200).json({ data: serializeTargets(row) });
  });

  getWater = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as DateQuery;
    const date = q.date ?? today();
    const entries = await this.water.getForDate(req.userId as string, date);
    res.status(200).json({ data: { date, consumedMl: entries.reduce((s, e) => s + e.amount_ml, 0) } });
  });

  addWater = asyncHandler(async (req, res) => {
    const body = req.validatedBody as AddWaterBody;
    const date = body.date ?? today();
    await this.water.add(req.userId as string, date, body.amountMl);
    const entries = await this.water.getForDate(req.userId as string, date);
    res.status(201).json({ data: { date, consumedMl: entries.reduce((s, e) => s + e.amount_ml, 0) } });
  });

  removeLastWater = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as DateQuery;
    const date = q.date ?? today();
    await this.water.deleteLast(req.userId as string, date);
    const entries = await this.water.getForDate(req.userId as string, date);
    res.status(200).json({ data: { date, consumedMl: entries.reduce((s, e) => s + e.amount_ml, 0) } });
  });
}
