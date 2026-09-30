import { asyncHandler } from '../../utils/asyncHandler';
import { FoodRecognitionService } from './foodRecognition.service';
import { ScanFoodBody } from './foodRecognition.validation';

export class FoodRecognitionController {
  constructor(private readonly service: FoodRecognitionService) {}

  scan = asyncHandler(async (req, res) => {
    const body = req.validatedBody as ScanFoodBody;
    const result = await this.service.scan(body.imageBase64, body.mimeType);
    res.status(200).json({ data: result });
  });
}
