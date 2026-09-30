-- Синонимы/альтернативные названия продукта — расширяют поиск
-- (например "гречка" / "гречневая крупа" / "buckwheat").
CREATE TABLE IF NOT EXISTS food_aliases (
    id                BIGSERIAL PRIMARY KEY,
    food_id           UUID NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    alias             TEXT NOT NULL,
    normalized_alias  TEXT NOT NULL,

    UNIQUE (food_id, normalized_alias)
);

CREATE INDEX IF NOT EXISTS idx_food_aliases_food_id ON food_aliases (food_id);
CREATE INDEX IF NOT EXISTS idx_food_aliases_trgm
    ON food_aliases USING GIN (normalized_alias gin_trgm_ops);
