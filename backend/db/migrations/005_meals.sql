-- Приёмы пищи. user_id пока не ссылается на таблицу users (её ещё нет —
-- в приложении нет полноценной авторизации), это просто UUID устройства/
-- аккаунта, который присылает Flutter (см. middleware/deviceUser.ts).
-- Когда появится настоящая авторизация, значение в этой колонке
-- останется тем же по смыслу — просто станет id из таблицы users.
CREATE TABLE IF NOT EXISTS meals (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL,
    type        TEXT NOT NULL CHECK (type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    date        DATE NOT NULL,
    time        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (user_id, type, date)
);

CREATE INDEX IF NOT EXISTS idx_meals_user_date ON meals (user_id, date);

DROP TRIGGER IF EXISTS trg_meals_updated_at ON meals;
CREATE TRIGGER trg_meals_updated_at
    BEFORE UPDATE ON meals
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Продукт внутри приёма пищи. Либо ссылается на каталог (food_id), либо
-- это ручной ввод без сохранения в общий каталог — тогда custom_nutrients
-- содержит нутриенты на 100 г, custom_name — название для показа.
CREATE TABLE IF NOT EXISTS meal_items (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_id           UUID NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
    food_id           UUID REFERENCES foods(id),
    custom_name       TEXT,
    custom_nutrients  JSONB,
    grams             NUMERIC(8, 2) NOT NULL CHECK (grams >= 0),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (food_id IS NOT NULL OR (custom_name IS NOT NULL AND custom_nutrients IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS idx_meal_items_meal_id ON meal_items (meal_id);
