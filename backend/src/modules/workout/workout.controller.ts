import { asyncHandler } from '../../utils/asyncHandler';
import { WorkoutProgramGenerator } from './workoutProgramGenerator.service';
import { WorkoutProfileRepository } from './workoutProfile.repository';
import { WorkoutProfileRow } from './workoutProfile.model';
import { WorkoutService } from './workout.service';
import { serializeProgram, serializeSession } from './workout.serializer';
import { CreateProgramBody, CreateSessionBody, UpdateWorkoutProfileBody } from './workout.validation';

function serializeWorkoutProfile(row: WorkoutProfileRow | null) {
  return {
    experience: row?.experience ?? null,
    place: row?.place ?? null,
    equipment: row?.equipment ?? [],
    workoutsPerWeek: row?.workouts_per_week ?? null,
    duration: row?.duration ?? null,
  };
}

export class WorkoutController {
  constructor(
    private readonly service: WorkoutService,
    private readonly profiles: WorkoutProfileRepository,
    private readonly generator: WorkoutProgramGenerator,
  ) {}

  /** GET /workout-profile — анкета онбординга (тренировочная часть). */
  getProfile = asyncHandler(async (req, res) => {
    const row = await this.profiles.find(req.userId as string);
    res.status(200).json({ data: serializeWorkoutProfile(row) });
  });

  /** PUT /workout-profile — частичное сохранение, как и /nutrition/profile. */
  updateProfile = asyncHandler(async (req, res) => {
    const body = req.validatedBody as UpdateWorkoutProfileBody;
    const row = await this.profiles.upsert(req.userId as string, body);
    res.status(200).json({ data: serializeWorkoutProfile(row) });
  });

  /**
   * POST /workout-programs/generate — Workout Program Generator: профиль ->
   * сплит по дням -> подбор упражнений из реального каталога -> сохранённая
   * программа (см. workoutProgramGenerator.service.ts). Ошибка
   * IncompleteWorkoutProfileError всплывает до errorHandler (422), как и
   * IncompleteNutritionProfileError у Nutrition Target Service.
   */
  generateProgram = asyncHandler(async (req, res) => {
    const program = await this.generator.generate(req.userId as string);
    res.status(201).json({ data: serializeProgram(program) });
  });

  /** POST /workout-programs */
  createProgram = asyncHandler(async (req, res) => {
    const body = req.validatedBody as CreateProgramBody;
    const program = await this.service.createProgram(req.userId as string, body);
    res.status(201).json({ data: serializeProgram(program) });
  });

  /** GET /workout-programs — собственные (созданные) программы пользователя. */
  listPrograms = asyncHandler(async (req, res) => {
    const programs = await this.service.listPrograms(req.userId as string);
    res.status(200).json({ data: programs.map(serializeProgram) });
  });

  /** DELETE /workout-programs/:id */
  deleteProgram = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    await this.service.deleteProgram(req.userId as string, id);
    res.status(204).send();
  });

  /** POST /workout-sessions */
  createSession = asyncHandler(async (req, res) => {
    const body = req.validatedBody as CreateSessionBody;
    const session = await this.service.createSession(req.userId as string, body);
    res.status(201).json({ data: serializeSession(session) });
  });

  /** GET /workout-sessions — вся история тренировок (календарь/статистика/личные рекорды). */
  listSessions = asyncHandler(async (req, res) => {
    const sessions = await this.service.listSessions(req.userId as string);
    res.status(200).json({ data: sessions.map(serializeSession) });
  });
}
