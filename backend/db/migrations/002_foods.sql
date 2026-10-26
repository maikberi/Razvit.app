-- Основная таблица продуктов Food Database.
-- Все нутриенты нормализованы к единому базису: на 100 г ИЛИ на 100 мл
-- (см. basis_unit) — то, что было в исходном продукте (порция, стакан,
-- унция и т.д.), пересчитывается в это при импорте (см. backend/src normalize.ts),
-- а исходная порция сохраняется отдельно в serving_size/serving_unit.
CREATE TABLE IF NOT EXISTS foods (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name             TEXT NOT NULL,
    normalized_name  TEXT NOT NULL, -- lowercase, без диакритики/пунктуации — для поиска и дедупликации
    brand            TEXT,
    barcode          TEXT,
    category         TEXT,

    source           TEXT NOT NULL CHECK (source IN ('RAZVIT', 'USDA', 'OFF')),
    source_id        TEXT, -- id продукта во внешнем источнике; NULL для source='RAZVIT'

    -- Нутриенты — всегда на 100 basis_unit (100 г или 100 мл).
    basis_unit       TEXT NOT NULL DEFAULT 'g' CHECK (basis_unit IN ('g', 'ml')),
    calories         NUMERIC(8, 2) NOT NULL CHECK (calories >= 0),
    protein          NUMERIC(8, 2) NOT NULL CHECK (protein >= 0),
    fat              NUMERIC(8, 2) NOT NULL CHECK (fat >= 0),
    carbohydrates    NUMERIC(8, 2) NOT NULL CHECK (carbohydrates >= 0),
    fiber            NUMERIC(8, 2) NOT NULL DEFAULT 0 CHECK (fiber >= 0),
    sugar            NUMERIC(8, 2) CHECK (sugar IS NULL OR sugar >= 0),
    sodium           NUMERIC(8, 3) CHECK (sodium IS NULL OR sodium >= 0), -- мг

    -- Информация о "порции по умолчанию", отдельно от нормализационного базиса.
    serving_size     NUMERIC(8, 2) CHECK (serving_size IS NULL OR serving_size > 0),
    serving_unit     TEXT,

    verified         BOOLEAN NOT NULL DEFAULT FALSE,

    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Защита от дублей: один и тот же штрихкод не может встретиться дважды,
-- независимо от источника (RAZVIT/USDA/OFF).
CREATE UNIQUE INDEX IF NOT EXISTS idx_foods_barcode_unique
    ON foods (barcode) WHERE barcode IS NOT NULL;

-- Защита от дублей: одна и та же запись из конкретного внешнего источника
-- не может быть импортирована дважды (повторный импорт — это UPDATE, не INSERT).
CREATE UNIQUE INDEX IF NOT EXISTS idx_foods_source_unique
    ON foods (source, source_id) WHERE source_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_foods_category ON foods (category) WHERE category IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_foods_source ON foods (source);

-- Fuzzy-поиск (устойчивый к опечаткам) по названию и бренду.
CREATE INDEX IF NOT EXISTS idx_foods_normalized_name_trgm
    ON foods USING GIN (normalized_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_foods_brand_trgm
    ON foods USING GIN (brand gin_trgm_ops) WHERE brand IS NOT NULL;

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_foods_updated_at ON foods;
CREATE TRIGGER trg_foods_updated_at
    BEFORE UPDATE ON foods
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
