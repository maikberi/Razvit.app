-- Недавно использованные продукты — для быстрого добавления на Nutrition
-- Home Screen. Обновляется автоматически при добавлении продукта в
-- приём пищи (см. meal.service.ts).
CREATE TABLE IF NOT EXISTS recent_foods (
    user_id       UUID NOT NULL,
    food_id       UUID NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    last_used_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    use_count     INT NOT NULL DEFAULT 1,

    PRIMARY KEY (user_id, food_id)
);

CREATE INDEX IF NOT EXISTS idx_recent_foods_user ON recent_foods (user_id, last_used_at DESC);
