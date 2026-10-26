-- Данные онбординга (тренировочная часть), которые Workout Program
-- Generator использует для сборки персональной программы (сколько дней
-- в неделю, опыт, где тренируется, какое оборудование доступно,
-- длительность тренировки) — см. workoutProgramGenerator.service.ts.
-- Цель тренировок (goal) сюда не дублируется: тот же самый выбор
-- пользователя в анкете онбординга уже сохраняется как
-- nutrition_profiles.goal, генератор читает его оттуда.
CREATE TABLE IF NOT EXISTS workout_profiles (
    user_id           UUID PRIMARY KEY,
    experience        TEXT CHECK (experience IN ('beginner', 'intermediate', 'advanced')),
    place             TEXT CHECK (place IN ('gym', 'home', 'outdoor', 'mixed')),
    -- Нет NOT NULL/DEFAULT: '{}' сработал бы только если колонку вообще
    -- не упоминать в INSERT, а upsert() ниже всегда передаёт значение (в
    -- т.ч. явный NULL при первом сохранении анкеты без equipment) —
    -- с NOT NULL это ловило бы constraint violation на самом первом PUT.
    equipment         TEXT[],
    workouts_per_week INT CHECK (workouts_per_week > 0 AND workouts_per_week <= 7),
    duration          TEXT CHECK (duration IN ('short', 'medium', 'long', 'extended', 'veryLong')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_workout_profiles_updated_at ON workout_profiles;
CREATE TRIGGER trg_workout_profiles_updated_at
    BEFORE UPDATE ON workout_profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
