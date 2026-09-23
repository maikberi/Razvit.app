import Anthropic, { APIConnectionError, APIConnectionTimeoutError, APIError, RateLimitError } from '@anthropic-ai/sdk';
import { z } from 'zod';
import { env } from '../config/env';

export const recognizedItemSchema = z.object({
  name: z.string(),
  estimated_grams: z.number().positive(),
  confidence: z.number().min(0).max(1),
  possible_alternatives: z.array(z.string()).optional(),
  uncertainty: z.string().optional(),
});

export const recognitionResultSchema = z.object({
  items: z.array(recognizedItemSchema),
  notes: z.string().optional(),
});

export type VisionRecognizedItem = z.infer<typeof recognizedItemSchema>;
export type VisionRecognitionResult = z.infer<typeof recognitionResultSchema>;

export type ImageMediaType = 'image/jpeg' | 'image/png' | 'image/webp';

export class VisionNotConfiguredError extends Error {
  constructor() {
    super('Vision AI is not configured on this server');
    this.name = 'VisionNotConfiguredError';
  }
}

/** Покрывает недоступность самого сервиса — сеть, 5xx, перегрузку, неверный ключ, неразбираемый ответ. */
export class VisionUnavailableError extends Error {
  constructor(message = 'Vision AI is temporarily unavailable') {
    super(message);
    this.name = 'VisionUnavailableError';
  }
}

export class VisionRateLimitError extends Error {
  constructor() {
    super('Vision AI rate limit exceeded');
    this.name = 'VisionRateLimitError';
  }
}

export class VisionTimeoutError extends Error {
  constructor() {
    super('Vision AI request timed out');
    this.name = 'VisionTimeoutError';
  }
}

const SYSTEM_PROMPT = `Ты помогаешь распознавать еду на фотографии для приложения контроля питания RAZVIT.

Твоя единственная задача — посмотреть на фото и перечислить, какие отдельные продукты/блюда на нём видны,
и оценить вес каждой порции в граммах. Ты НЕ считаешь калории и БЖУ — это делает база данных приложения
и отдельный расчётный движок, не ты. Просто называй продукты и оценивай вес.

Правила:
- Называй продукты по-русски, простыми обиходными названиями, как их называют в обычном магазине или
  дневнике питания (например "куриная грудка", а не "grilled chicken breast fillet").
- Если на фото составное блюдо из нескольких явно различимых компонентов (например курица + рис + овощи
  на одной тарелке), перечисли их как отдельные элементы списка, а не одним пунктом.
- Оценивай вес на глаз по видимому объёму порции, в граммах.
- Указывай уверенность (confidence) честно: если сомневаешься между двумя похожими продуктами — снижай
  уверенность и перечисляй альтернативы, а не выбирай наугад с высокой уверенностью.
- Если еды на фото не видно вообще (пустая тарелка, не еда, неразборчиво) — верни пустой список items,
  не пытайся угадать.

Ответь СТРОГО в виде JSON-объекта по заданной схеме, без пояснений и без markdown-обёртки.`;

// Raw JSON Schema (а не сгенерированный из zod) — сознательно: у SDK
// зависимость от zod ^3.25 || ^4, а весь остальной backend — на zod ^3.24
// (см. validation.ts во всех модулях); смешивать две версии зависимости
// ради одного эндпоинта не стоит. Ответ модели разбирается и проверяется
// той же zod v3 схемой (recognitionResultSchema) вручную, см. ниже.
const RESPONSE_JSON_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          estimated_grams: { type: 'number' },
          confidence: { type: 'number' },
          possible_alternatives: { type: 'array', items: { type: 'string' } },
          uncertainty: { type: 'string' },
        },
        required: ['name', 'estimated_grams', 'confidence'],
        additionalProperties: false,
      },
    },
    notes: { type: 'string' },
  },
  required: ['items'],
  additionalProperties: false,
} as const;

/**
 * Клиент Vision AI (Claude) для распознавания еды на фото — единственное
 * место в backend, где вызывается внешняя модель. Возвращает только
 * название + оценку веса + уверенность, НИКОГДА не КБЖУ — это принципиально:
 * реальные нутриенты всегда берутся из Food Database и считаются
 * Nutrition Engine (см. foodRecognition.service.ts), AI не источник истины
 * для КБЖУ.
 */
export class VisionClient {
  private readonly client: Anthropic | null;

  constructor() {
    this.client = env.anthropicApiKey ? new Anthropic({ apiKey: env.anthropicApiKey, timeout: 25000, maxRetries: 1 }) : null;
  }

  async recognizeFood(imageBase64: string, mediaType: ImageMediaType): Promise<VisionRecognitionResult> {
    if (!this.client) throw new VisionNotConfiguredError();

    try {
      const response = await this.client.messages.create({
        model: env.visionModel,
        max_tokens: 2048,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'image', source: { type: 'base64', media_type: mediaType, data: imageBase64 } },
              { type: 'text', text: 'Что за еда на этом фото? Перечисли продукты и оцени вес каждого в граммах.' },
            ],
          },
        ],
        output_config: { format: { type: 'json_schema', schema: RESPONSE_JSON_SCHEMA } },
      });

      const textBlock = response.content.find((b): b is Anthropic.TextBlock => b.type === 'text');
      if (!textBlock) {
        throw new VisionUnavailableError('Vision AI returned no text response');
      }

      let raw: unknown;
      try {
        raw = JSON.parse(textBlock.text);
      } catch {
        throw new VisionUnavailableError('Vision AI returned a response that was not valid JSON');
      }

      const parsed = recognitionResultSchema.safeParse(raw);
      if (!parsed.success) {
        throw new VisionUnavailableError('Vision AI returned a response that did not match the expected format');
      }
      return parsed.data;
    } catch (err) {
      if (err instanceof VisionUnavailableError) throw err;
      if (err instanceof APIConnectionTimeoutError) throw new VisionTimeoutError();
      if (err instanceof RateLimitError) throw new VisionRateLimitError();
      if (err instanceof APIConnectionError) throw new VisionUnavailableError('Network error contacting Vision AI');
      if (err instanceof APIError) throw new VisionUnavailableError(err.message);
      throw err;
    }
  }
}
