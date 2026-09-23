-- Вход через Google: пароль больше не обязателен (аккаунт может быть
-- создан только через Google), добавляем google_id для связи с учёткой
-- Google (её "sub" из id-токена).
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE;
