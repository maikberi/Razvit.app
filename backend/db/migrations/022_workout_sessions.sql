-- Зафиксированные тренировки (факт выполнения) — сейчас во Flutter это
-- статичный мок (mock_sessions.dart) и in-memory состояние активной
-- тренировки (activeWorkoutProvider): закрыл приложение — прогресс,
-- история подходов, календарь и статистика тренировок обнуляются.
--
-- program_id ссылается на workout_programs, но тренировку можно записать
-- и по встроенной (не хранящейся в БД) программе — тогда program_id NULL,
-- а program_day_id хранит клиентский id дня ('day_1' и т.п.) как обычный
-- текст, без FK.
--
-- exercise_logs — вложенная структура (упражнение → список подходов),
-- ровно как ExerciseLog/SetLog во Flutter; личные рекорды и история по
-- конкретному упражнению считаются на клиенте агрегацией по всем сессиям
-- пользователя — так один и тот же массив сессий питает и календарь,
-- и статистику, и историю упражнения, без отдельных таблиц/эндпоинтов.
CREATE TABLE IF NOT EXISTS workout_sessions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL,
    program_id        UUID REFERENCES workout_programs(id) ON DELETE SET NULL,
    program_day_id    TEXT,
    date              TIMESTAMPTZ NOT NULL,
    title             TEXT NOT NULL,
    status            TEXT NOT NULL DEFAULT 'done' CHECK (status IN ('done', 'planned', 'missed')),
    duration_minutes  INT NOT NULL DEFAULT 0 CHECK (duration_minutes >= 0),
    calories          INT NOT NULL DEFAULT 0 CHECK (calories >= 0),
    -- [{ "exerciseId": "...", "exerciseName": "...", "comment": null, "sets": [{ "weightKg": 60, "reps": 8, "completed": true }] }]
    exercise_logs     JSONB NOT NULL DEFAULT '[]',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_workout_sessions_user_date ON workout_sessions (user_id, date);
