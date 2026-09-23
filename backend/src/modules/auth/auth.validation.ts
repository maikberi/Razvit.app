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
