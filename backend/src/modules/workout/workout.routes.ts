import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { validate } from '../../middleware/validate';
import { WorkoutController } from './workout.controller';
import { WorkoutRepository } from './workout.repository';
import { WorkoutService } from './workout.service';
import { createProgramSchema, createSessionSchema, programIdParamSchema } from './workout.validation';

const repository = new WorkoutRepository(pool);
const service = new WorkoutService(repository);
const controller = new WorkoutController(service);

export const workoutRouter = Router();

workoutRouter.get('/workout-programs', authUser, controller.listPrograms);
workoutRouter.post('/workout-programs', authUser, validate(createProgramSchema, 'body'), controller.createProgram);
workoutRouter.delete('/workout-programs/:id', authUser, validate(programIdParamSchema, 'params'), controller.deleteProgram);

workoutRouter.get('/workout-sessions', authUser, controller.listSessions);
workoutRouter.post('/workout-sessions', authUser, validate(createSessionSchema, 'body'), controller.createSession);

export { WorkoutController, WorkoutRepository, WorkoutService };
