import { z } from 'zod';

export const registerSchema = z.object({
  email: z.string().trim().toLowerCase().email('email должен быть валидным'),
  password: z.string().min(8, 'пароль должен быть не короче 8 символов').max(200),
  name: z.string().trim().min(1, 'имя обязательно').max(120),
});
export type RegisterBody = z.infer<typeof registerSchema>;

export const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email('email должен быть валидным'),
  password: z.string().min(1, 'пароль обязателен'),
});
export type LoginBody = z.infer<typeof loginSchema>;

export const googleAuthSchema = z.object({
  idToken: z.string().min(1, 'idToken обязателен'),
});
export type GoogleAuthBody = z.infer<typeof googleAuthSchema>;

export const vkAuthSchema = z.object({
  code: z.string().min(1, 'code обязателен'),
  deviceId: z.string().min(1, 'deviceId обязателен'),
  codeVerifier: z.string().min(1, 'codeVerifier обязателен'),
  redirectUri: z.string().min(1, 'redirectUri обязателен'),
  state: z.string().min(1, 'state обязателен'),
});
export type VkAuthBody = z.infer<typeof vkAuthSchema>;

export const telegramAuthSchema = z.object({
  id: z.union([z.string(), z.number()]),
  first_name: z.string().min(1),
  last_name: z.string().optional(),
  username: z.string().optional(),
  photo_url: z.string().optional(),
  auth_date: z.union([z.string(), z.number()]),
  hash: z.string().min(1),
});
export type TelegramAuthBody = z.infer<typeof telegramAuthSchema>;

// avatarUrl — data URL (data:image/...;base64,...) целиком в JSON-теле, тот
// же подход, что уже используется для фото в AI Food Recognition (см.
// app.ts — лимит тела запроса 8mb специально под base64-фото). ~700 000
// символов base64 — с запасом хватает на фото профиля после client-side
// сжатия (image_picker: maxWidth/maxHeight/imageQuality, см. Flutter).
export const updateUserProfileSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  lastName: z.string().trim().max(120).nullable().optional(),
  nickname: z.string().trim().max(60).nullable().optional(),
  avatarUrl: z.string().trim().max(700_000).startsWith('data:image/').nullable().optional(),
});
export type UpdateUserProfileBody = z.infer<typeof updateUserProfileSchema>;
