-- Данные пользователя, нужные Nutrition Target Service для расчёта
-- calorie/macro/water целей (BMR/TDEE -> Goal adjustment -> Calories ->
-- Macros, см. nutritionTarget.service.ts). Отдельно от users (не всем
-- нужны эти поля сразу) и отдельно от nutrition_targets (там уже готовые,
-- изменяемые пользователем цели — здесь только исходные данные для расчёта).
-- Все поля nullable — профиль можно заполнять постепенно; расчёт целей
-- требует, чтобы все они были заданы (см. IncompleteNutritionProfileError).
CREATE TABLE IF NOT EXISTS nutrition_profiles (
    user_id         UUID PRIMARY KEY,
    sex             TEXT CHECK (sex IN ('male', 'female')),
    age             INT CHECK (age > 0 AND age < 120),
    height_cm       NUMERIC CHECK (height_cm > 0),
    weight_kg       NUMERIC CHECK (weight_kg > 0),
    activity_level  TEXT CHECK (activity_level IN ('sedentary', 'light', 'moderate', 'active', 'very_active')),
    goal            TEXT CHECK (goal IN ('lose_weight', 'gain_muscle', 'get_stronger', 'improve_shape', 'endurance', 'maintain')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_nutrition_profiles_updated_at ON nutrition_profiles;
CREATE TRIGGER trg_nutrition_profiles_updated_at
    BEFORE UPDATE ON nutrition_profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
