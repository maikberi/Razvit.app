import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { publicCatalogRateLimiter } from '../../middleware/rateLimiter';
import { validate } from '../../middleware/validate';
import { ExerciseController } from './exercise.controller';
import { ExerciseRepository } from './exercise.repository';
import { ExerciseService } from './exercise.service';
import { idParamSchema, searchQuerySchema } from './exercise.validation';

const repository = new ExerciseRepository(pool);
const service = new ExerciseService(repository);
const controller = new ExerciseController(service);

export const exerciseRouter = Router();

exerciseRouter.get('/exercises', publicCatalogRateLimiter, validate(searchQuerySchema, 'query'), controller.list);
// /exercises/favorites — до /exercises/:id, иначе Express примет "favorites" за id.
exerciseRouter.get('/exercises/favorites', authUser, controller.listFavorites);
exerciseRouter.get('/exercises/:id', validate(idParamSchema, 'params'), controller.getById);
exerciseRouter.post('/exercises/:id/favorite', authUser, validate(idParamSchema, 'params'), controller.addFavorite);
exerciseRouter.delete('/exercises/:id/favorite', authUser, validate(idParamSchema, 'params'), controller.removeFavorite);

export { ExerciseController, ExerciseRepository, ExerciseService };
