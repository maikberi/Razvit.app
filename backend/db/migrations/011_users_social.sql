-- Вход через VK и Telegram — так же, как Google: без пароля, со своим id.
ALTER TABLE users ADD COLUMN IF NOT EXISTS vk_id TEXT UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS telegram_id TEXT UNIQUE;
