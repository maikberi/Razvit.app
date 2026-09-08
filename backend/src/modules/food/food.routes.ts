import { Router } from 'express';
import { pool } from '../../db/pool';
import { deviceUser } from '../../middleware/deviceUser';
import { validate } from '../../middleware/validate';
import { FoodController } from './food.controller';
import { FoodRepository } from './food.repository';
import { FoodSearchService } from './food.search.service';
import { FoodService } from './food.service';
import { barcodeParamSchema, createFoodSchema, idParamSchema, searchQuerySchema } from './food.validation';

const repository = new FoodRepository(pool);
const service = new FoodService(repository);
const searchService = new FoodSearchService(service);
const controller = new FoodController(service, searchService);

export const foodRouter = Router();

foodRouter.get('/foods', validate(searchQuerySchema, 'query'), controller.list);
foodRouter.get('/foods/search', validate(searchQuerySchema, 'query'), controller.search);
foodRouter.get('/foods/barcode/:barcode', validate(barcodeParamSchema, 'params'), controller.getByBarcode);
// /foods/recent — до /foods/:id, иначе Express примет "recent" за id.
foodRouter.get('/foods/recent', deviceUser, controller.getRecent);
foodRouter.get('/foods/:id', validate(idParamSchema, 'params'), controller.getById);
foodRouter.post('/foods', validate(createFoodSchema, 'body'), controller.create);

// Экспортируем для тестов, которым нужны собранные вручную экземпляры на своём pool.
export { FoodController, FoodRepository, FoodSearchService, FoodService };
