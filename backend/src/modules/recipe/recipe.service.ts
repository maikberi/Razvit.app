import { FoodRepository } from '../food/food.repository';
import { FoodRow, PagedResult } from '../food/food.model';
import { ForbiddenError } from '../meal/meal.service';
import { NutritionCalculationService } from '../nutrition/nutrition.calculation.service';
import { FoodAmount, NutrientProfile, NutrientSource } from '../nutrition/nutrition.model';
import { RecipeRepository } from './recipe.repository';
import { RecipeIngredientInput, RecipeIngredientRow, RecipeInput, RecipeRow, RecipeSearchParams, RecipeUnit } from './recipe.model';

export class RecipeNotFoundError extends Error {
  constructor() {
    super('Recipe not found');
    this.name = 'RecipeNotFoundError';
  }
}

/** Ингредиент в 'pcs' (штуках) у продукта без заданного serving_size — перевести в граммы нечем. */
export class RecipeIngredientUnitError extends Error {
  constructor(
    public readonly foodId: string,
    public readonly foodName: string,
  ) {
    super(`Food "${foodName}" has no serving size defined — cannot use unit "pcs"`);
    this.name = 'RecipeIngredientUnitError';
  }
}

export interface RecipeIngredientDetail {
  foodId: string;
  foodName: string;
  foodImageUrl: string | null;
  foodEmoji: string | null;
  quantity: number;
  unit: RecipeUnit;
  grams: number;
}

export interface RecipeWithDetails {
  recipe: RecipeRow;
  ingredients: RecipeIngredientDetail[];
  nutrition: { total: NutrientProfile; perServing: NutrientProfile };
  isFavorite: boolean;
  isOwner: boolean;
}

function toNutrientSource(food: FoodRow): NutrientSource {
  return {
    calories: Number(food.calories),
    protein: Number(food.protein),
    fat: Number(food.fat),
    carbohydrates: Number(food.carbohydrates),
    fiber: Number(food.fiber),
    sugar: food.sugar != null ? Number(food.sugar) : null,
    sodium: food.sodium != null ? Number(food.sodium) : null,
  };
}

/**
 * Переводит количество ингредиента в граммы/мл — базис, который
 * понимает NutritionCalculationService. 'g'/'ml' — это уже тот же
 * базис, что и у продукта (basis_unit), берём как есть. 'pcs' — через
 * serving_size продукта ("1 штука = N г/мл", то же поле, что уже
 * показывает Flutter как "1 порция"); без него посчитать нельзя.
 */
function toGrams(food: FoodRow, quantity: number, unit: RecipeUnit): number {
  if (unit !== 'pcs') return quantity;
  if (food.serving_size == null) {
    throw new RecipeIngredientUnitError(food.id, food.name);
  }
  return quantity * Number(food.serving_size);
}

/**
 * Рецепты: CRUD + расчёт нутриентов из ингредиентов через тот же
 * NutritionCalculationService, что и Meal/Day. Нутриенты нигде не
 * хранятся — считаются заново при каждом обращении (список тоже грузит
 * продукты одним батч-запросом, без N+1), поэтому изменение ингредиента
 * автоматически отражается в результате без какой-либо инвалидации кэша.
 */
export class RecipeService {
  constructor(
    private readonly repo: RecipeRepository,
    private readonly foods: FoodRepository,
    private readonly engine: NutritionCalculationService,
  ) {}

  async create(userId: string, input: RecipeInput): Promise<RecipeWithDetails> {
    const foodsById = await this.loadFoods(input.ingredients.map((i) => i.foodId));
    this.validateIngredients(input.ingredients, foodsById);
    const { recipe, ingredients } = await this.repo.create(userId, input);
    return this.assemble(recipe, ingredients, foodsById, false, true);
  }

  async update(userId: string, id: string, input: RecipeInput): Promise<RecipeWithDetails> {
    const existing = await this.repo.findById(id);
    if (!existing) throw new RecipeNotFoundError();
    if (existing.user_id !== userId) throw new ForbiddenError();

    const foodsById = await this.loadFoods(input.ingredients.map((i) => i.foodId));
    this.validateIngredients(input.ingredients, foodsById);
    const result = await this.repo.update(id, input);
    if (!result) throw new RecipeNotFoundError();

    const isFavorite = await this.repo.isFavorite(userId, id);
    return this.assemble(result.recipe, result.ingredients, foodsById, isFavorite, true);
  }

  async delete(userId: string, id: string): Promise<void> {
    const existing = await this.repo.findById(id);
    if (!existing) throw new RecipeNotFoundError();
    if (existing.user_id !== userId) throw new ForbiddenError();
    await this.repo.delete(id);
  }

  async getById(userId: string, id: string): Promise<RecipeWithDetails> {
    const recipe = await this.repo.findById(id);
    if (!recipe) throw new RecipeNotFoundError();
    const ingredients = await this.repo.getIngredients(id);
    const foodsById = await this.loadFoods(ingredients.map((i) => i.food_id));
    const isFavorite = await this.repo.isFavorite(userId, id);
    return this.assemble(recipe, ingredients, foodsById, isFavorite, recipe.user_id === userId);
  }

  async list(userId: string, params: Omit<RecipeSearchParams, 'userId'>): Promise<PagedResult<RecipeWithDetails>> {
    const page = await this.repo.search({ ...params, userId });
    const recipeIds = page.items.map((r) => r.id);
    const [allIngredients, favoriteIds] = await Promise.all([
      this.repo.getIngredientsForRecipes(recipeIds),
      this.repo.favoritesForUser(userId, recipeIds),
    ]);
    const foodsById = await this.loadFoods(allIngredients.map((i) => i.food_id));

    const ingredientsByRecipe = new Map<string, RecipeIngredientRow[]>();
    for (const ing of allIngredients) {
      const list = ingredientsByRecipe.get(ing.recipe_id) ?? [];
      list.push(ing);
      ingredientsByRecipe.set(ing.recipe_id, list);
    }

    const items = page.items.map((recipe) =>
      this.assemble(
        recipe,
        ingredientsByRecipe.get(recipe.id) ?? [],
        foodsById,
        favoriteIds.has(recipe.id),
        recipe.user_id === userId,
      ),
    );
    return { ...page, items };
  }

  async favorite(userId: string, id: string): Promise<void> {
    const recipe = await this.repo.findById(id);
    if (!recipe) throw new RecipeNotFoundError();
    await this.repo.addFavorite(userId, id);
  }

  async unfavorite(userId: string, id: string): Promise<void> {
    await this.repo.removeFavorite(userId, id);
  }

  private async loadFoods(ids: string[]): Promise<Map<string, FoodRow>> {
    const unique = [...new Set(ids)];
    const rows = await this.foods.findByIds(unique);
    return new Map(rows.map((f) => [f.id, f]));
  }

  private validateIngredients(items: RecipeIngredientInput[], foodsById: Map<string, FoodRow>): void {
    for (const item of items) {
      const food = foodsById.get(item.foodId);
      if (!food) throw new RecipeIngredientFoodNotFoundError(item.foodId);
      toGrams(food, item.quantity, item.unit); // бросит RecipeIngredientUnitError, если 'pcs' не посчитать
    }
  }

  private assemble(
    recipe: RecipeRow,
    ingredientRows: RecipeIngredientRow[],
    foodsById: Map<string, FoodRow>,
    isFavorite: boolean,
    isOwner: boolean,
  ): RecipeWithDetails {
    const amounts: FoodAmount[] = [];
    const ingredients: RecipeIngredientDetail[] = ingredientRows.map((ing) => {
      const food = foodsById.get(ing.food_id);
      if (!food) throw new RecipeIngredientFoodNotFoundError(ing.food_id);
      const quantity = Number(ing.quantity);
      const grams = toGrams(food, quantity, ing.unit);
      amounts.push({ food: toNutrientSource(food), grams });
      return {
        foodId: food.id,
        foodName: food.name,
        foodImageUrl: food.image_url,
        foodEmoji: food.emoji,
        quantity,
        unit: ing.unit,
        grams,
      };
    });
    const nutrition = this.engine.forRecipe(amounts, Number(recipe.servings));
    return { recipe, ingredients, nutrition, isFavorite, isOwner };
  }
}

/** Ингредиент ссылается на food_id, которого нет в базе (не должно происходить — foods нельзя удалить, пока на них ссылается рецепт). */
export class RecipeIngredientFoodNotFoundError extends Error {
  constructor(public readonly foodId: string) {
    super(`Food ${foodId} not found`);
    this.name = 'RecipeIngredientFoodNotFoundError';
  }
}
