import { asyncHandler } from '../../utils/asyncHandler';
import { RecipeGeneratorService } from './recipeGenerator.service';
import { GenerateRecipeBody } from './recipeGenerator.validation';

export class RecipeGeneratorController {
  constructor(private readonly service: RecipeGeneratorService) {}

  generate = asyncHandler(async (req, res) => {
    const body = req.validatedBody as GenerateRecipeBody;
    const recipe = await this.service.generate(body.prompt);
    res.status(200).json({ data: recipe });
  });
}
