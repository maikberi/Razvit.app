-- Библиотека упражнений (Exercise Database) — раньше это были только мок-данные
-- во Flutter (lib/data/mock/mock_exercises.dart), без бэкенда и без медиа
-- у 24 из 25 упражнений. Теперь — настоящий каталог с анимированными GIF.
CREATE TABLE IF NOT EXISTS exercises (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug              TEXT NOT NULL UNIQUE, -- стабильный ключ из источника, для повторного импорта/обновления
    name              TEXT NOT NULL,
    muscle_group      TEXT NOT NULL CHECK (muscle_group IN ('chest', 'back', 'legs', 'shoulders', 'arms', 'abs', 'cardio')),
    secondary_muscles TEXT[] NOT NULL DEFAULT '{}',
    equipment         TEXT NOT NULL,
    difficulty        TEXT NOT NULL CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
    instructions      TEXT[] NOT NULL DEFAULT '{}',
    gif_url           TEXT,
    thumb_url         TEXT,
    -- 'EXTERNAL' — импортировано из стороннего датасета (см. 018_exercise_seed.sql);
    -- 'RAZVIT' зарезервировано под будущие собственные/авторские упражнения.
    source            TEXT NOT NULL DEFAULT 'EXTERNAL' CHECK (source IN ('RAZVIT', 'EXTERNAL')),

    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_exercises_muscle_group ON exercises (muscle_group);
CREATE INDEX IF NOT EXISTS idx_exercises_equipment ON exercises (equipment);
CREATE INDEX IF NOT EXISTS idx_exercises_difficulty ON exercises (difficulty);

DROP TRIGGER IF EXISTS trg_exercises_updated_at ON exercises;
CREATE TRIGGER trg_exercises_updated_at
    BEFORE UPDATE ON exercises
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Избранные упражнения пользователя. Без FK на users(id) — намеренно,
-- по той же причине, что и везде в проекте (см. аудит ЭТАП 18): тесты
-- подписывают JWT для синтетических UUID без реальной строки в users.
CREATE TABLE IF NOT EXISTS exercise_favorites (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL,
    exercise_id  UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, exercise_id)
);

CREATE INDEX IF NOT EXISTS idx_exercise_favorites_user ON exercise_favorites (user_id);
