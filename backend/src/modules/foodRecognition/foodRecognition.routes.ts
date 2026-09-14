import { Router } from 'express';
import { pool } from '../../db/pool';
import { authUser } from '../../middleware/authUser';
import { validate } from '../../middleware/validate';
import { VisionClient } from '../../integrations/visionClient';
import { FoodRepository } from '../food/food.repository';
import { FoodMatchingService } from '../food/food.matching';
import { NutritionCalculationService } from '../nutrition/nutrition.calculation.service';
import { FoodRecognitionController } from './foodRecognition.controller';
import { FoodRecognitionService } from './foodRecognition.service';
import { scanFoodSchema } from './foodRecognition.validation';

const foodRepository = new FoodRepository(pool);
const matching = new FoodMatchingService(foodRepository);
const engine = new NutritionCalculationService();
const visionClient = new VisionClient();
const service = new FoodRecognitionService(visionClient, matching, engine);
const controller = new FoodRecognitionController(service);

export const foodRecognitionRouter = Router();

foodRecognitionRouter.post('/food-recognition/scan', authUser, validate(scanFoodSchema, 'body'), controller.scan);

// Экспортируем для тестов, которым нужны собранные вручную экземпляры с фейковым VisionClient.
export { FoodRecognitionController, FoodRecognitionService };
