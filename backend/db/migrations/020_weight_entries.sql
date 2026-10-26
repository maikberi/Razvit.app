-- Записи веса пользователя — сейчас во Flutter это статичный мок
-- (mock_progress.dart), реального ввода/сохранения нет. Отдельные записи
-- (а не одно число на пользователя), как water_entries — есть история,
-- можно удалить ошибочную запись.
CREATE TABLE IF NOT EXISTS weight_entries (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL,
    weight_kg   NUMERIC(5, 1) NOT NULL CHECK (weight_kg > 0),
    logged_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_weight_entries_user_logged ON weight_entries (user_id, logged_at);
