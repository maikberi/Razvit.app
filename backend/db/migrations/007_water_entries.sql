-- Учёт выпитой воды — отдельные записи (а не одно число), чтобы была
-- история и можно было отменить последнее добавление.
CREATE TABLE IF NOT EXISTS water_entries (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL,
    date        DATE NOT NULL,
    amount_ml   INT NOT NULL CHECK (amount_ml > 0),
    logged_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_water_entries_user_date ON water_entries (user_id, date);
