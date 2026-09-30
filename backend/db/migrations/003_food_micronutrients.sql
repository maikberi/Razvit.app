-- Расширяемая структура микронутриентов: ключ-значение вместо жёстких колонок,
-- чтобы добавлять новые микронутриенты (калий, витамин C, кальций и т.д.)
-- без миграций схемы.
CREATE TABLE IF NOT EXISTS food_micronutrients (
    id         BIGSERIAL PRIMARY KEY,
    food_id    UUID NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    key        TEXT NOT NULL,   -- напр. 'potassium', 'vitamin_c', 'calcium', 'iron'
    amount     NUMERIC(10, 4) NOT NULL,
    unit       TEXT NOT NULL,   -- 'mg', 'mcg', 'iu' и т.д.

    UNIQUE (food_id, key)
);

CREATE INDEX IF NOT EXISTS idx_food_micronutrients_food_id ON food_micronutrients (food_id);
