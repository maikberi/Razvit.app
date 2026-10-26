-- Расширения PostgreSQL, нужные Food Database:
--  pgcrypto — генерация UUID для id продуктов;
--  pg_trgm  — триграммный (fuzzy/опечаточный) поиск по названию/бренду/алиасам.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
