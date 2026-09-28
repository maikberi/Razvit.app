import { asyncHandler } from '../../utils/asyncHandler';
import { WorkoutService } from './workout.service';
import { serializeProgram, serializeSession } from './workout.serializer';
import { CreateProgramBody, CreateSessionBody } from './workout.validation';

export class WorkoutController {
  constructor(private readonly service: WorkoutService) {}

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
