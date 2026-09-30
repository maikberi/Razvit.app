-- Программы тренировок, созданные пользователем (create_program_screen.dart).
-- Сейчас они живут только в памяти вкладки (customProgramsProvider,
-- обычный StateNotifier) — обновил страницу и всё пропало. Встроенные
-- программы (Push/Pull/Legs и т.п. из mock_programs.dart) остаются
-- клиентскими константами, здесь хранятся только созданные пользователем.
--
-- Дни программы и упражнения в них хранятся как JSONB одним куском —
-- это план (сколько подходов/повторов/веса запланировано), а не факт
-- выполнения, вложенность заранее известна и целиком приходит/уходит
-- одним curl-запросом с Flutter, отдельные таблицы под это usage не дают
-- ничего, кроме лишних join'ов.
CREATE TABLE IF NOT EXISTS workout_programs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL,
    title         TEXT NOT NULL,
    goal          TEXT NOT NULL CHECK (goal IN ('mass', 'loss', 'strength', 'definition', 'maintenance')),
    level         TEXT NOT NULL CHECK (level IN ('beginner', 'intermediate', 'advanced')),
    total_weeks   INT NOT NULL DEFAULT 8 CHECK (total_weeks > 0),
    training_days INT[] NOT NULL DEFAULT '{}',
    -- [{ "id": "day_1", "title": "...", "exercises": [{ "exerciseId": "...", "sets": 3, "repsLabel": "8-10", "weightKg": 20, "restSeconds": 60 }] }]
    days          JSONB NOT NULL DEFAULT '[]',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_workout_programs_user ON workout_programs (user_id, created_at);

DROP TRIGGER IF EXISTS trg_workout_programs_updated_at ON workout_programs;
CREATE TRIGGER trg_workout_programs_updated_at
    BEFORE UPDATE ON workout_programs
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
