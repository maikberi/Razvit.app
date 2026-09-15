import Anthropic, { APIConnectionError, APIConnectionTimeoutError, APIError, RateLimitError } from '@anthropic-ai/sdk';
import { z } from 'zod';
import { env } from '../config/env';

export const recipeDraftIngredientSchema = z.object({
  name: z.string(),
  quantity: z.number().positive(),
  unit: z.enum(['g', 'ml', 'pcs']),
});

export const recipeDraftConstraintsSchema = z.object({
  minCalories: z.number().min(0).optional(),
  maxCalories: z.number().min(0).optional(),
  minProtein: z.number().min(0).optional(),
  maxProtein: z.number().min(0).optional(),
  minFat: z.number().min(0).optional(),
  maxFat: z.number().min(0).optional(),
  minCarbohydrates: z.number().min(0).optional(),
  maxCarbohydrates: z.number().min(0).optional(),
});

export const recipeDraftSchema = z.object({
  name: z.string(),
  description: z.string().optional(),
  servings: z.number().positive(),
  cookingTimeMinutes: z.number().min(0).optional(),
  instructions: z.string(),
  ingredients: z.array(recipeDraftIngredientSchema).min(1),
  constraints: recipeDraftConstraintsSchema.optional(),
});

export type RecipeDraftIngredient = z.infer<typeof recipeDraftIngredientSchema>;
export type RecipeDraftConstraints = z.infer<typeof recipeDraftConstraintsSchema>;
export type RecipeDraft = z.infer<typeof recipeDraftSchema>;

export class RecipeAiNotConfiguredError extends Error {
  constructor() {
    super('Recipe generation AI is not configured on this server');
    this.name = 'RecipeAiNotConfiguredError';
  }
}

/** Покрывает недоступность самого сервиса — сеть, 5xx, перегрузку, неверный ключ, неразбираемый ответ. */
export class RecipeAiUnavailableError extends Error {
  constructor(message = 'Recipe generation AI is temporarily unavailable') {
    super(message);
    this.name = 'RecipeAiUnavailableError';
  }
}

export class RecipeAiRateLimitError extends Error {
  constructor() {
    super('Recipe generation AI rate limit exceeded');
    this.name = 'RecipeAiRateLimitError';
  }
}

export class RecipeAiTimeoutError extends Error {
  constructor() {
    super('Recipe generation AI request timed out');
    this.name = 'RecipeAiTimeoutError';
  }
}

const SYSTEM_PROMPT = `Ты помогаешь придумывать рецепты для приложения контроля питания RAZVIT по текстовому запросу пользователя.

Твоя задача — придумать рецепт: название, короткое описание, число порций, время готовки в минутах, пошаговую
инструкцию и список ингредиентов с количествами. Также извлеки из запроса пользователя явные числовые
ограничения на КБЖУ ОДНОЙ ПОРЦИИ, если пользователь их указал (например "до 600 ккал" -> maxCalories: 600,
"минимум 40 г белка" -> minProtein: 40). Если пользователь не называл конкретных чисел — не придумывай
ограничения, оставь constraints пустым объектом.

Ты НЕ считаешь итоговые калории и БЖУ рецепта — это делает Food Database и Nutrition Engine приложения по
реальным данным о продуктах, не ты. Твоя часть работы — только подобрать реалистичные ингредиенты, их
количество и понятные шаги готовки.

Правила:
- Называй ингредиенты по-русски простыми обиходными названиями, по которым их можно найти в базе продуктов
  (например "куриная грудка", "рис", "оливковое масло"), без брендов и без сложных кулинарных терминов
  в самом названии ингредиента.
- quantity — положительное число, unit — одно из "g" (граммы), "ml" (миллилитры) или "pcs" (штуки — только
  для по-настоящему штучных продуктов вроде яйца).
- instructions — связный пошаговый текст на русском языке.

Ответь СТРОГО в виде JSON-объекта по заданной схеме, без пояснений и без markdown-обёртки.`;

// Raw JSON Schema, а не сгенерированная из zod — та же причина, что и у
// VisionClient (см. visionClient.ts): SDK требует zod ^3.25 || ^4, а
// остальной backend — на zod ^3.24. Ответ разбирается и проверяется той же
// zod v3 схемой (recipeDraftSchema) вручную, см. ниже.
const RESPONSE_JSON_SCHEMA = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    description: { type: 'string' },
    servings: { type: 'number' },
    cookingTimeMinutes: { type: 'number' },
    instructions: { type: 'string' },
    ingredients: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          quantity: { type: 'number' },
          unit: { type: 'string', enum: ['g', 'ml', 'pcs'] },
        },
        required: ['name', 'quantity', 'unit'],
        additionalProperties: false,
      },
    },
    constraints: {
      type: 'object',
      properties: {
        minCalories: { type: 'number' },
        maxCalories: { type: 'number' },
        minProtein: { type: 'number' },
        maxProtein: { type: 'number' },
        minFat: { type: 'number' },
        maxFat: { type: 'number' },
        minCarbohydrates: { type: 'number' },
        maxCarbohydrates: { type: 'number' },
      },
      additionalProperties: false,
    },
  },
  required: ['name', 'servings', 'instructions', 'ingredients'],
  additionalProperties: false,
} as const;

/**
 * Клиент AI Recipe Generator (Claude) — придумывает рецепт (название,
 * ингредиенты, количества, инструкцию) и распознаёт запрошенные
 * пользователем ограничения на КБЖУ. Никогда не возвращает итоговые
 * калории/БЖУ — их считает RecipeGeneratorService через Food Database +
 * Nutrition Engine (см. recipeGenerator.service.ts), AI не источник истины
 * для КБЖУ, как и в AI Food Recognition.
 */
export class RecipeGeneratorClient {
  private readonly client: Anthropic | null;

  constructor() {
    this.client = env.anthropicApiKey ? new Anthropic({ apiKey: env.anthropicApiKey, timeout: 30000, maxRetries: 1 }) : null;
  }

  /**
   * @param feedback Если задан — это повторная попытка: добавляем к запросу
   * пользователя факт о том, что дал предыдущий вариант, и что нужно
   * поправить, чтобы точнее попасть в ограничения.
   */
  async generate(prompt: string, feedback?: string): Promise<RecipeDraft> {
    if (!this.client) throw new RecipeAiNotConfiguredError();

    const userText = feedback ? `${prompt}\n\n${feedback}` : prompt;

    try {
      const response = await this.client.messages.create({
        model: env.visionModel,
        max_tokens: 2048,
        system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: userText }],
        output_config: { format: { type: 'json_schema', schema: RESPONSE_JSON_SCHEMA } },
      });

      const textBlock = response.content.find((b): b is Anthropic.TextBlock => b.type === 'text');
      if (!textBlock) {
        throw new RecipeAiUnavailableError('Recipe generation AI returned no text response');
      }

      let raw: unknown;
      try {
        raw = JSON.parse(textBlock.text);
      } catch {
        throw new RecipeAiUnavailableError('Recipe generation AI returned a response that was not valid JSON');
      }

      const parsed = recipeDraftSchema.safeParse(raw);
      if (!parsed.success) {
        throw new RecipeAiUnavailableError('Recipe generation AI returned a response that did not match the expected format');
      }
      return parsed.data;
    } catch (err) {
      if (err instanceof RecipeAiUnavailableError) throw err;
      if (err instanceof APIConnectionTimeoutError) throw new RecipeAiTimeoutError();
      if (err instanceof RateLimitError) throw new RecipeAiRateLimitError();
      if (err instanceof APIConnectionError) throw new RecipeAiUnavailableError('Network error contacting Recipe generation AI');
      if (err instanceof APIError) throw new RecipeAiUnavailableError(err.message);
      throw err;
    }
  }
}
