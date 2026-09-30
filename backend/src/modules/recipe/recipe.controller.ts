import { asyncHandler } from '../../utils/asyncHandler';
import { RecipeInputBody, RecipeSearchQuery } from './recipe.validation';
import { RecipeService } from './recipe.service';
import { serializeRecipe, serializeRecipePage } from './recipe.serializer';

export class RecipeController {
  constructor(private readonly service: RecipeService) {}

  list = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as RecipeSearchQuery;
    const page = await this.service.list(req.userId as string, q);
    res.status(200).json(serializeRecipePage(page));
  });

  getById = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    const recipe = await this.service.getById(req.userId as string, id);
    res.status(200).json({ data: serializeRecipe(recipe) });
  });

  create = asyncHandler(async (req, res) => {
    const body = req.validatedBody as RecipeInputBody;
    const recipe = await this.service.create(req.userId as string, body);
    res.status(201).json({ data: serializeRecipe(recipe) });
  });

  update = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    const body = req.validatedBody as RecipeInputBody;
    const recipe = await this.service.update(req.userId as string, id, body);
    res.status(200).json({ data: serializeRecipe(recipe) });
  });

  remove = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    await this.service.delete(req.userId as string, id);
    res.status(204).send();
  });

  favorite = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    await this.service.favorite(req.userId as string, id);
    res.status(204).send();
  });

  unfavorite = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    await this.service.unfavorite(req.userId as string, id);
    res.status(204).send();
  });
}
