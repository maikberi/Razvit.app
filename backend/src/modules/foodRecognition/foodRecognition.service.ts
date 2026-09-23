import { FoodRow } from '../food/food.model';
import { FoodMatchingService, FoodMatchTier } from '../food/food.matching';
import { NutritionCalculationService } from '../nutrition/nutrition.calculation.service';
import { NutrientSource } from '../nutrition/nutrition.model';
import { ImageMediaType, VisionClient, VisionRecognizedItem } from '../../integrations/visionClient';
import { FoodRecognitionResult, RecognizedFoodItem } from './foodRecognition.model';

// Ступени сопоставления, которые сами по себе достаточно надёжны, чтобы не
// требовать подтверждения от пользователя (при достаточной уверенности AI).
const STRONG_MATCH_TIERS: FoodMatchTier[] = ['exact', 'alias'];
// Ниже этого порога уверенность самого AI в том, что на фото вообще этот
// продукт, слишком низкая, чтобы показывать результат без подтверждения.
const MIN_CONFIDENCE_FOR_AUTO_ACCEPT = 0.7;

/** Декодированное изображение больше не подходит по размеру/содержимому. */
export class InvalidImageError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InvalidImageError';
  }
}

// После base64-декодирования — реальный размер файла. Flutter уже должен
// сжимать фото перед отправкой (см. scan_food_screen.dart), это —
// защитный предел на backend, который никогда не доверяет клиенту.
const MAX_IMAGE_BYTES = 6 * 1024 * 1024;

const MAGIC_BYTES: Record<ImageMediaType, number[][]> = {
  'image/jpeg': [[0xff, 0xd8, 0xff]],
  'image/png': [[0x89, 0x50, 0x4e, 0x47]],
  'image/webp': [[0x52, 0x49, 0x46, 0x46]], // 'RIFF' — WEBP подтверждается байтами 8-11 ('WEBP'), проверяем отдельно
};

function matchesMagicBytes(buffer: Buffer, mediaType: ImageMediaType): boolean {
  const signatures = MAGIC_BYTES[mediaType];
  const matchesAny = signatures.some((sig) => sig.every((byte, i) => buffer[i] === byte));
  if (!matchesAny) return false;
  if (mediaType === 'image/webp') {
    return buffer.length >= 12 && buffer.subarray(8, 12).toString('ascii') === 'WEBP';
  }
  return true;
}

function toNutrientSource(food: FoodRow): NutrientSource {
  return {
    calories: Number(food.calories),
    protein: Number(food.protein),
    fat: Number(food.fat),
    carbohydrates: Number(food.carbohydrates),
    fiber: Number(food.fiber),
    sugar: food.sugar != null ? Number(food.sugar) : null,
    sodium: food.sodium != null ? Number(food.sodium) : null,
  };
}

/**
 * AI Food Recognition — оркестрирует весь путь фото -> результат:
 * валидация изображения -> Vision AI (только называет продукты и
 * оценивает вес) -> сопоставление с Food Database -> расчёт КБЖУ через
 * Nutrition Engine. Vision AI никогда не является источником истины для
 * КБЖУ — если продукт не находится в базе, nutrition для него остаётся
 * null и пользователь должен выбрать реальный продукт вручную (см.
 * RecognizedFoodItem.matchedFoodId).
 */
export class FoodRecognitionService {
  constructor(
    private readonly vision: VisionClient,
    private readonly matching: FoodMatchingService,
    private readonly engine: NutritionCalculationService,
  ) {}

  async scan(imageBase64: string, mimeType: ImageMediaType): Promise<FoodRecognitionResult> {
    const buffer = this.decodeImage(imageBase64, mimeType);
    const recognition = await this.vision.recognizeFood(buffer.toString('base64'), mimeType);

    const items = await Promise.all(recognition.items.map((item) => this.toRecognizedItem(item)));
    return { items, notes: recognition.notes ?? null };
  }

  private decodeImage(imageBase64: string, mimeType: ImageMediaType): Buffer {
    let buffer: Buffer;
    try {
      buffer = Buffer.from(imageBase64, 'base64');
    } catch {
      throw new InvalidImageError('imageBase64 could not be decoded');
    }
    if (buffer.length === 0) {
      throw new InvalidImageError('Decoded image is empty');
    }
    if (buffer.length > MAX_IMAGE_BYTES) {
      throw new InvalidImageError(`Image exceeds the ${MAX_IMAGE_BYTES / (1024 * 1024)}MB limit`);
    }
    if (!matchesMagicBytes(buffer, mimeType)) {
      throw new InvalidImageError('Image content does not match the declared mimeType');
    }
    return buffer;
  }

  private async toRecognizedItem(item: VisionRecognizedItem): Promise<RecognizedFoodItem> {
    const result = await this.matching.match(item.name);
    const food = result?.food ?? null;
    const nutrition = food ? this.engine.forFoodAmount(toNutrientSource(food), item.estimated_grams) : null;
    const needsConfirmation = this.needsConfirmation(item.confidence, result?.tier ?? null);

    return {
      aiName: item.name,
      estimatedGrams: item.estimated_grams,
      confidence: item.confidence,
      possibleAlternatives: item.possible_alternatives ?? [],
      uncertainty: item.uncertainty ?? null,
      matchedFoodId: food?.id ?? null,
      matchedFoodName: food?.name ?? null,
      matchedFoodImageUrl: food?.image_url ?? null,
      matchedFoodEmoji: food?.emoji ?? null,
      matchedBasisUnit: food?.basis_unit ?? null,
      matchTier: result?.tier ?? null,
      matchScore: result?.score ?? null,
      needsConfirmation,
      nutrition,
    };
  }

  /**
   * Автоматически принимаем результат (не требуем подтверждения) только
   * когда совпали ОБА условия: сопоставление найдено на надёжной ступени
   * (exact/alias) И сам AI достаточно уверен, что на фото именно этот
   * продукт. Слабая ступень (fuzzy/category) или низкая уверенность AI —
   * всегда просим пользователя подтвердить или изменить; отсутствие
   * совпадения — тем более.
   */
  private needsConfirmation(aiConfidence: number, tier: FoodMatchTier | null): boolean {
    if (!tier) return true;
    if (!STRONG_MATCH_TIERS.includes(tier)) return true;
    return aiConfidence < MIN_CONFIDENCE_FOR_AUTO_ACCEPT;
  }
}
