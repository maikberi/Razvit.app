-- Рецепты. Нутриенты (total/perServing) НЕ хранятся здесь — считаются на
-- лету из recipe_ingredients через тот же NutritionCalculationService,
-- что и Meal/Day (см. RecipeService). Кэш намеренно не заводим: список
-- ингредиентов в рецепте маленький (обычно 3-15 строк), а батч-загрузка
-- продуктов уже используется для Meal/Day тем же способом — считать на
-- лету дешевле и надёжнее, чем городить инвалидацию кэша при каждом
-- изменении ингредиента.
-- user_id намеренно без FK на users — как и во всех остальных таблицах
-- с user_id в проекте (meals, nutrition_targets и т.д.), см. их миграции:
-- исторически это был device_id, и тесты подписывают JWT на произвольный
-- UUID без реальной строки в users (см. tests/testAuth.ts).
CREATE TABLE IF NOT EXISTS recipes (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID NOT NULL,

    name                  TEXT NOT NULL,
    description           TEXT,
    image_url             TEXT,
    servings              NUMERIC(6, 2) NOT NULL CHECK (servings > 0),
    cooking_time_minutes  INTEGER CHECK (cooking_time_minutes IS NULL OR cooking_time_minutes >= 0),
    instructions          TEXT NOT NULL,

    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ингредиент рецепта: продукт из Food Database + количество в одной из
-- трёх единиц. 'pcs' (штуки, например "2 яйца") переводится в граммы
-- через foods.serving_size продукта — см. RecipeService.toGrams.
CREATE TABLE IF NOT EXISTS recipe_ingredients (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id   UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    food_id     UUID NOT NULL REFERENCES foods(id),
    quantity    NUMERIC(8, 2) NOT NULL CHECK (quantity > 0),
    unit        TEXT NOT NULL CHECK (unit IN ('g', 'ml', 'pcs')),
    position    INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS recipe_favorites (
    user_id     UUID NOT NULL,
    recipe_id   UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, recipe_id)
);

CREATE INDEX IF NOT EXISTS idx_recipes_user ON recipes (user_id);
CREATE INDEX IF NOT EXISTS idx_recipes_name_trgm ON recipes USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON recipe_ingredients (recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_favorites_user ON recipe_favorites (user_id);

DROP TRIGGER IF EXISTS trg_recipes_updated_at ON recipes;
CREATE TRIGGER trg_recipes_updated_at
    BEFORE UPDATE ON recipes
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
