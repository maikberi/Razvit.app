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
