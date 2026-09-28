import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { validate } from '../../middleware/validate';
import { ProgressController } from './progress.controller';
import { ProgressRepository } from './progress.repository';
import { ProgressService } from './progress.service';
import { addWeightEntrySchema, weightEntryIdParamSchema } from './progress.validation';

const repository = new ProgressRepository(pool);
const service = new ProgressService(repository);
const controller = new ProgressController(service);

export const progressRouter = Router();

progressRouter.get('/weight-entries', authUser, controller.listWeightEntries);
progressRouter.post('/weight-entries', authUser, validate(addWeightEntrySchema, 'body'), controller.addWeightEntry);
progressRouter.delete('/weight-entries/:id', authUser, validate(weightEntryIdParamSchema, 'params'), controller.deleteWeightEntry);

export { ProgressController, ProgressRepository, ProgressService };
