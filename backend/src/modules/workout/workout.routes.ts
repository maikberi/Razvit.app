import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { validate } from '../../middleware/validate';
import { ExerciseRepository } from '../exercise/exercise.repository';
import { NutritionProfileRepository } from '../nutrition/nutritionProfile.repository';
import { WorkoutController } from './workout.controller';
import { WorkoutRepository } from './workout.repository';
import { WorkoutService } from './workout.service';
import { createProgramSchema, createSessionSchema, programIdParamSchema, updateWorkoutProfileSchema } from './workout.validation';
import { WorkoutProfileRepository } from './workoutProfile.repository';
import { WorkoutProgramGenerator } from './workoutProgramGenerator.service';

const repository = new WorkoutRepository(pool);
const service = new WorkoutService(repository);
const workoutProfileRepository = new WorkoutProfileRepository(pool);
const nutritionProfileRepository = new NutritionProfileRepository(pool);
const exerciseRepository = new ExerciseRepository(pool);
const generator = new WorkoutProgramGenerator(workoutProfileRepository, nutritionProfileRepository, exerciseRepository, repository);
const controller = new WorkoutController(service, workoutProfileRepository, generator);

export const workoutRouter = Router();

workoutRouter.get('/workout-programs', authUser, controller.listPrograms);
workoutRouter.post('/workout-programs', authUser, validate(createProgramSchema, 'body'), controller.createProgram);
workoutRouter.post('/workout-programs/generate', authUser, controller.generateProgram);
workoutRouter.delete('/workout-programs/:id', authUser, validate(programIdParamSchema, 'params'), controller.deleteProgram);

workoutRouter.get('/workout-profile', authUser, controller.getProfile);
workoutRouter.put('/workout-profile', authUser, validate(updateWorkoutProfileSchema, 'body'), controller.updateProfile);

workoutRouter.get('/workout-sessions', authUser, controller.listSessions);
workoutRouter.post('/workout-sessions', authUser, validate(createSessionSchema, 'body'), controller.createSession);

export { WorkoutController, WorkoutRepository, WorkoutService };
