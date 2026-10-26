-- ЭТАП 17: связь тренер-клиент + то, что тренер назначает клиенту.
-- Единственное место во всём проекте, которое решает, кто кому может
-- видеть данные о питании — см. trainer.access.service.ts, который
-- проверяет approved-строку здесь на КАЖДОМ обращении тренера к данным
-- конкретного клиента (никогда не полагаемся на проверку во Flutter).

ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'client' CHECK (role IN ('client', 'trainer'));

CREATE TABLE IF NOT EXISTS trainer_clients (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id    UUID NOT NULL,
    client_id     UUID NOT NULL,
    status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined', 'revoked')),
    -- Разрешил ли клиент тренеру видеть фото еды. Само хранение фото к
    -- конкретной записи дневника в проекте пока не реализовано (foods.image_url —
    -- это картинка из каталога продукта, а не фото, которое сделал пользователь) —
    -- флаг существует, чтобы политика доступа была на месте уже сейчас.
    share_photos  BOOLEAN NOT NULL DEFAULT false,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (trainer_id <> client_id),
    UNIQUE (trainer_id, client_id)
);

CREATE INDEX IF NOT EXISTS idx_trainer_clients_trainer ON trainer_clients (trainer_id, status);
CREATE INDEX IF NOT EXISTS idx_trainer_clients_client ON trainer_clients (client_id, status);

DROP TRIGGER IF EXISTS trg_trainer_clients_updated_at ON trainer_clients;
CREATE TRIGGER trg_trainer_clients_updated_at
    BEFORE UPDATE ON trainer_clients
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- "Coach Plan" + "Daily Target", которые клиент видит на своей стороне.
-- Один активный план на клиента (не на пару тренер-клиент) — упрощение,
-- чтобы клиенту не показывать несколько конкурирующих целей одновременно.
CREATE TABLE IF NOT EXISTS coach_nutrition_plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id       UUID NOT NULL UNIQUE,
    trainer_id      UUID NOT NULL,
    title           TEXT,
    calorie_target  INT CHECK (calorie_target >= 0),
    protein_target  INT CHECK (protein_target >= 0),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_coach_nutrition_plans_updated_at ON coach_nutrition_plans;
CREATE TRIGGER trg_coach_nutrition_plans_updated_at
    BEFORE UPDATE ON coach_nutrition_plans
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- "Assigned Meals": либо ссылка на рецепт (назначить recipe), либо
-- произвольный текстовый план питания (создать meal plan) — то и другое
-- одна и та же сущность с точки зрения клиента: что-то, что назначил тренер.
CREATE TABLE IF NOT EXISTS coach_meal_assignments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id  UUID NOT NULL,
    client_id   UUID NOT NULL,
    recipe_id   UUID REFERENCES recipes(id),
    title       TEXT NOT NULL,
    notes       TEXT,
    meal_type   TEXT CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coach_meal_assignments_client ON coach_meal_assignments (client_id, created_at);

-- "Coach Comments": рекомендации и комментарии тренера — одна и та же
-- по смыслу произвольная текстовая заметка от тренера клиенту.
CREATE TABLE IF NOT EXISTS coach_comments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id  UUID NOT NULL,
    client_id   UUID NOT NULL,
    message     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coach_comments_client ON coach_comments (client_id, created_at);
