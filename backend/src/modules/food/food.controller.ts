import { NextFunction, Request, Response } from 'express';
import { FoodService } from './food.service';
import { FoodSearchService } from './food.search.service';
import { serializeFood, serializePage } from './food.serializer';
import { CreateFoodBody, SearchQuery } from './food.validation';

function asyncHandler(fn: (req: Request, res: Response, next: NextFunction) => Promise<void>) {
  return (req: Request, res: Response, next: NextFunction) => {
    fn(req, res, next).catch(next);
  };
}

export class FoodController {
  constructor(
    private readonly foodService: FoodService,
    private readonly searchService: FoodSearchService,
  ) {}

  /** GET /foods — список/поиск с пагинацией, сортировкой и фильтрами. */
  list = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as SearchQuery;
    const page = await this.searchService.search({
      query: q.q,
      barcode: q.barcode,
      category: q.category,
      source: q.source,
      page: q.page,
      perPage: q.perPage,
      sort: q.sort,
    });
    res.status(200).json(serializePage(page));
  });

  /** GET /foods/search?q= — то же самое, отдельный путь для читаемости API. */
  search = this.list;

  /** GET /foods/:id */
  getById = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    const food = await this.foodService.getById(id);
    const micronutrients = await this.foodService.getMicronutrients(food.id);
    res.status(200).json({ data: serializeFood(food, micronutrients) });
  });

  /** GET /foods/barcode/:barcode — локально, при отсутствии — подтягивает Open Food Facts. */
  getByBarcode = asyncHandler(async (req, res) => {
    const { barcode } = req.validatedParams as { barcode: string };
    const food = await this.searchService.lookupBarcode(barcode);
    if (!food) {
      res.status(404).json({ error: { code: 'FOOD_NOT_FOUND', message: 'Продукт с таким штрихкодом не найден' } });
      return;
    }
    const micronutrients = await this.foodService.getMicronutrients(food.id);
    res.status(200).json({ data: serializeFood(food, micronutrients) });
  });

  /** POST /foods — создание собственного (source=RAZVIT) продукта. 409 при дубле по штрихкоду. */
  create = asyncHandler(async (req, res) => {
    const body = req.validatedBody as CreateFoodBody;
    const food = await this.foodService.createOwn({
      name: body.name,
      brand: body.brand ?? null,
      barcode: body.barcode ?? null,
      category: body.category ?? null,
      source: 'RAZVIT',
      sourceId: null,
      basisUnit: body.basisUnit,
      calories: body.calories,
      protein: body.protein,
      fat: body.fat,
      carbohydrates: body.carbohydrates,
      fiber: body.fiber,
      sugar: body.sugar ?? null,
      sodium: body.sodium ?? null,
      servingSize: body.servingSize ?? null,
      servingUnit: body.servingUnit ?? null,
      verified: true,
      micronutrients: body.micronutrients,
      aliases: body.aliases,
    });
    res.status(201).json({ data: serializeFood(food) });
  });
}
