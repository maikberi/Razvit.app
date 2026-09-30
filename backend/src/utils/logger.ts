/**
 * Минимальный структурированный лог — без внешней библиотеки (никаких
 * других логов в проекте пока нет, полноценный winston/pino был бы
 * избыточен). Пишет одну JSON-строку в stdout, её видно в логах Yandex
 * Cloud Function.
 *
 * Намеренно НЕ принимает и не пишет ничего похожего на персональные
 * данные (email, имя, IP, сырой ответ AI целиком, фото) — вызывающий
 * код должен передавать только то, что нужно для отладки пайплайна
 * (какие продукты, какая уверенность, что с чем сопоставилось).
 */
export function logEvent(event: string, data: Record<string, unknown> = {}): void {
  // eslint-disable-next-line no-console
  console.log(JSON.stringify({ event, ts: new Date().toISOString(), ...data }));
}
