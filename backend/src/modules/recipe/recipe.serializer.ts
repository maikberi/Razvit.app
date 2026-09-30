import { PagedResult } from '../food/food.model';
import { RecipeUnit } from './recipe.model';
import { RecipeWithDetails } from './recipe.service';

export interface RecipeIngredientDTO {
  foodId: string;
  foodName: string;
  foodImageUrl: string | null;
  foodEmoji: string | null;
  quantity: number;
  unit: RecipeUnit;
  grams: number;
}

export interface RecipeDTO {
  id: string;
  name: string;
  description: string | null;
  imageUrl: string | null;
  servings: number;
  cookingTimeMinutes: number | null;
  instructions: string;
  ingredients: RecipeIngredientDTO[];
  nutrition: RecipeWithDetails['nutrition'];
  isFavorite: boolean;
  isOwner: boolean;
  createdAt: string;
  updatedAt: string;
}

export function serializeRecipe(details: RecipeWithDetails): RecipeDTO {
  const { recipe } = details;
  return {
    id: recipe.id,
    name: recipe.name,
    description: recipe.description,
    imageUrl: recipe.image_url,
    servings: Number(recipe.servings),
    cookingTimeMinutes: recipe.cooking_time_minutes,
    instructions: recipe.instructions,
    ingredients: details.ingredients,
    nutrition: details.nutrition,
    isFavorite: details.isFavorite,
    isOwner: details.isOwner,
    createdAt: recipe.created_at.toISOString(),
    updatedAt: recipe.updated_at.toISOString(),
  };
}

export function serializeRecipePage(page: PagedResult<RecipeWithDetails>) {
  return {
    data: page.items.map(serializeRecipe),
    meta: {
      page: page.page,
      perPage: page.perPage,
      total: page.total,
      totalPages: page.totalPages,
    },
  };
}
