import { asyncHandler } from '../../utils/asyncHandler';
import { NutritionAnalyticsService } from './nutritionAnalytics.service';
import { AnalyticsQuery } from './nutrition.validation';

export class NutritionAnalyticsController {
  constructor(private readonly service: NutritionAnalyticsService) {}

  /** GET /nutrition/analytics?period=7d|30d|90d — агрегированная статистика, backend считает всё. */
  getAnalytics = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as AnalyticsQuery;
    const result = await this.service.getAnalytics(req.userId as string, q.period);
    res.status(200).json({ data: result });
  });
}
