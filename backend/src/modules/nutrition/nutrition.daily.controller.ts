import { asyncHandler } from '../../utils/asyncHandler';
import { ForbiddenError } from '../meal/meal.service';
import { NutritionDailyService, WaterEntryNotFoundError } from './nutrition.daily.service';
import { NutritionProfileRepository } from './nutritionProfile.repository';
import { NutritionTargetService } from './nutritionTarget.service';
import { NutritionTargetsRepository } from './nutrition.targets.repository';
import { NutritionWaterRepository, WaterEntryRow } from './nutrition.water.repository';
import {
  AddWaterBody,
  DateQuery,
  UpdateNutritionProfileBody,
  UpdateTargetsBody,
  UpdateWaterEntryBody,
  WaterEntryIdParam,
} from './nutrition.validation';

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

function serializeWaterEntry(row: WaterEntryRow) {
  return { id: row.id, amountMl: row.amount_ml, loggedAt: row.logged_at.toISOString() };
}

function serializeProfile(row: Awaited<ReturnType<NutritionProfileRepository['find']>>) {
  return {
    sex: row?.sex ?? null,
    age: row?.age ?? null,
    heightCm: row?.height_cm != null ? Number(row.height_cm) : null,
    weightKg: row?.weight_kg != null ? Number(row.weight_kg) : null,
    activityLevel: row?.activity_level ?? null,
    goal: row?.goal ?? null,
  };
}

/** Nutrition Home Screen: дневная сводка, цели, вода, профиль для расчёта целей — то, что нужно per-пользователю. */
export class NutritionDailyController {
  constructor(
    private readonly daily: NutritionDailyService,
    private readonly targets: NutritionTargetsRepository,
    private readonly water: NutritionWaterRepository,
    private readonly profile: NutritionProfileRepository,
    private readonly targetService: NutritionTargetService,
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

  getProfile = asyncHandler(async (req, res) => {
    const row = await this.profile.find(req.userId as string);
    res.status(200).json({ data: serializeProfile(row) });
  });

  updateProfile = asyncHandler(async (req, res) => {
    const body = req.validatedBody as UpdateNutritionProfileBody;
    const row = await this.profile.upsert(req.userId as string, body);
    res.status(200).json({ data: serializeProfile(row) });
  });

  /**
   * POST /nutrition/targets/generate — Nutrition Target Service: профиль ->
   * BMR/TDEE -> goal adjustment -> calories -> macros (+ вода), и сразу
   * сохраняет результат как текущие цели (nutrition_targets), которые
   * пользователь по-прежнему может изменить вручную через PUT /nutrition/targets.
   */
  generateTargets = asyncHandler(async (req, res) => {
    const userId = req.userId as string;
    const profileRow = await this.profile.find(userId);
    const complete = this.targetService.toCompleteProfile(profileRow);
    const computed = this.targetService.computeTargets(complete);
    const row = await this.targets.upsert(userId, computed);
    res.status(200).json({ data: serializeTargets(row) });
  });

  getWater = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as DateQuery;
    const date = q.date ?? today();
    const entries = await this.water.getForDate(req.userId as string, date);
    res.status(200).json({ data: { date, consumedMl: entries.reduce((s, e) => s + e.amount_ml, 0), entries: entries.map(serializeWaterEntry) } });
  });

  addWater = asyncHandler(async (req, res) => {
    const body = req.validatedBody as AddWaterBody;
    const date = body.date ?? today();
    await this.water.add(req.userId as string, date, body.amountMl);
    const entries = await this.water.getForDate(req.userId as string, date);
    res.status(201).json({ data: { date, consumedMl: entries.reduce((s, e) => s + e.amount_ml, 0), entries: entries.map(serializeWaterEntry) } });
  });

  removeLastWater = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as DateQuery;
    const date = q.date ?? today();
    await this.water.deleteLast(req.userId as string, date);
    const entries = await this.water.getForDate(req.userId as string, date);
    res.status(200).json({ data: { date, consumedMl: entries.reduce((s, e) => s + e.amount_ml, 0), entries: entries.map(serializeWaterEntry) } });
  });

  updateWaterEntry = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as WaterEntryIdParam;
    const body = req.validatedBody as UpdateWaterEntryBody;
    const existing = await this.water.findById(id);
    if (!existing) throw new WaterEntryNotFoundError();
    if (existing.user_id !== (req.userId as string)) throw new ForbiddenError();

    await this.water.update(id, body.amountMl);
    const entries = await this.water.getForDate(existing.user_id, existing.date);
    res.status(200).json({ data: { date: existing.date, consumedMl: entries.reduce((s, e) => s + e.amount_ml, 0), entries: entries.map(serializeWaterEntry) } });
  });

  deleteWaterEntry = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as WaterEntryIdParam;
    const existing = await this.water.findById(id);
    if (!existing) throw new WaterEntryNotFoundError();
    if (existing.user_id !== (req.userId as string)) throw new ForbiddenError();

    await this.water.delete(id);
    const entries = await this.water.getForDate(existing.user_id, existing.date);
    res.status(200).json({ data: { date: existing.date, consumedMl: entries.reduce((s, e) => s + e.amount_ml, 0), entries: entries.map(serializeWaterEntry) } });
  });
}
