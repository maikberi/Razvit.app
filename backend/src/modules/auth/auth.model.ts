export interface UserRow {
  id: string;
  email: string;
  password_hash: string | null;
  name: string;
  google_id: string | null;
  vk_id: string | null;
  telegram_id: string | null;
  created_at: Date;
  updated_at: Date;
}

export type SocialProvider = 'google' | 'vk' | 'telegram';

export const SOCIAL_ID_COLUMNS: Record<SocialProvider, 'google_id' | 'vk_id' | 'telegram_id'> = {
  google: 'google_id',
  vk: 'vk_id',
  telegram: 'telegram_id',
};
