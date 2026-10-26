import { env } from '../../config/env';
import { asyncHandler } from '../../utils/asyncHandler';
import { FoodImportService } from './food.import.service';
import { ImportQuery } from './food.validation';

/**
 * Разовый (запускаемый вручную, по ссылке в браузере) импорт российских
 * продуктов из Open Food Facts. Не часть обычного API продуктов — этим
 * не пользуется приложение, только администратор при наполнении каталога.
 */
export class FoodImportController {
  constructor(private readonly importService: FoodImportService) {}

  importOffRussia = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as ImportQuery;
    if (!env.adminImportKey || q.key !== env.adminImportKey) {
      res.status(403).json({ error: { code: 'FORBIDDEN', message: 'Неверный или отсутствующий key' } });
      return;
    }
    const progress = await this.importService.importRussianProducts(q.page);
    res.status(200).json({
      data: {
        ...progress,
        nextPageHint: progress.done ? null : progress.lastPage + 1,
      },
    });
  });
}
