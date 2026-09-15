-- Фото продукта (сейчас реально приходит только от Open Food Facts —
-- у USDA и собственного каталога RAZVIT фотографий обычно нет, поле
-- просто остаётся NULL).
ALTER TABLE foods ADD COLUMN IF NOT EXISTS image_url TEXT;
