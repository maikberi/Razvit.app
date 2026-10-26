-- Раньше "Личные данные" в профиле были только для чтения — фамилия,
-- никнейм и фото менялись исключительно в локальном (не сохраняемом на
-- backend) Riverpod-состоянии и терялись при перезапуске/на другом
-- устройстве. avatar_url хранит фото как data URL (data:image/jpeg;base64,...)
-- прямо в колонке — фото профиля маленькое (см. ограничение размера в
-- updateProfileSchema и сжатие на клиенте через image_picker), заводить
-- отдельное файловое хранилище/S3 под это избыточно.
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS nickname TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
