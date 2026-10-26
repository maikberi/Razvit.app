import rateLimit from 'express-rate-limit';
import { env } from '../config/env';

// В тестах лимитер выключен: тесты намеренно бьют один и тот же эндпоинт
// (регистрация/AI) десятки раз в одном прогоне ради разных сценариев —
// это не тот "злоупотребление", от которого лимитер защищает в проде.
const skipInTests = () => env.nodeEnv === 'test';

// Раньше ни один эндпоинт ничем не был ограничен по частоте запросов —
// ни вход/регистрация (подбор пароля, спам регистраций), ни AI-эндпоинты
// (дорогие внешние вызовы к Anthropic — оплачиваются за токен, картинка в
// каждом запросе). См. аудит ЭТАП 18.
//
// В serverless-окружении (Yandex Cloud Function) лимит per-instance
// (в памяти), а не глобальный — это всё ещё полезный защитный слой
// (отсекает основную массу автоматизированного злоупотребления с одного
// источника в пределах "тёплого" инстанса), просто не абсолютная гарантия
// при множестве параллельных холодных стартов. Для этого масштаба
// проекта это осознанный компромисс: полноценный распределённый лимитер
// (Redis и т.п.) — отдельная инфраструктурная задача, не часть этого аудита.

function jsonRateLimitHandler(code: string, message: string) {
  return (_req: unknown, res: import('express').Response) => {
    res.status(429).json({ error: { code, message } });
  };
}

/** POST /auth/register, /auth/login, /auth/google, /auth/vk, /auth/telegram — защита от перебора пароля и спама регистраций. По IP, так как до этой точки пользователь ещё не аутентифицирован. */
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTests,
  handler: jsonRateLimitHandler('RATE_LIMITED', 'Слишком много попыток входа/регистрации, попробуй через несколько минут'),
});

/** POST /food-recognition/scan, /recipe-generator/generate — дорогие вызовы AI (оплата за токены/изображение). По userId (эндпоинт уже требует authUser), а не по IP — иначе несколько пользователей за одним NAT делили бы один лимит. */
export const aiRateLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  limit: 15,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTests,
  keyGenerator: (req) => req.userId ?? req.ip ?? 'unknown',
  handler: jsonRateLimitHandler('AI_RATE_LIMITED', 'Слишком много запросов к AI, попробуй через несколько минут'),
});

/** GET /foods, /foods/search, /foods/barcode/:barcode — публичные (без authUser) эндпоинты каталога. Штрихкод при промахе идёт во внешний Open Food Facts — без лимита анонимный вызывающий мог бы им злоупотреблять без ограничений. Лимит заметно мягче авторизационного — это обычный поиск при вводе текста, не подбор пароля. */
export const publicCatalogRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300,
  standardHeaders: true,
  legacyHeaders: false,
  skip: skipInTests,
  handler: jsonRateLimitHandler('RATE_LIMITED', 'Слишком много запросов, попробуй через несколько минут'),
});
