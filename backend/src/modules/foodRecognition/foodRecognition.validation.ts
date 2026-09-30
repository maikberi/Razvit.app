import { z } from 'zod';

// Реальный размер после base64-декодирования будет ~3/4 от длины строки —
// проверяем decoded-размер в сервисе (см. MAX_IMAGE_BYTES), здесь только
// защита от совсем безумных payload ещё до похода в сервис.
export const scanFoodSchema = z.object({
  imageBase64: z.string().min(1, 'imageBase64 is required').max(15_000_000, 'image is too large'),
  mimeType: z.enum(['image/jpeg', 'image/png', 'image/webp']),
});

export type ScanFoodBody = z.infer<typeof scanFoodSchema>;
