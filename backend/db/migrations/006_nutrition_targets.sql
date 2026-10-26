-- Личные цели по питанию (БЖУ/вода) — раньше жили только в мок-данных
-- Flutter (NutritionPlan), теперь настоящая запись на пользователя.
CREATE TABLE IF NOT EXISTS nutrition_targets (
    user_id        UUID PRIMARY KEY,
    title          TEXT NOT NULL DEFAULT 'Персональный план',
    calorie_goal   INT NOT NULL CHECK (calorie_goal >= 0),
    protein_goal   INT NOT NULL CHECK (protein_goal >= 0),
    fat_goal       INT NOT NULL CHECK (fat_goal >= 0),
    carbs_goal     INT NOT NULL CHECK (carbs_goal >= 0),
    water_goal_ml  INT NOT NULL CHECK (water_goal_ml >= 0),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_nutrition_targets_updated_at ON nutrition_targets;
CREATE TRIGGER trg_nutrition_targets_updated_at
    BEFORE UPDATE ON nutrition_targets
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
