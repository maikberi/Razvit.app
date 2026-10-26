export type UserRole = 'client' | 'trainer';

export interface UserRow {
  id: string;
  email: string;
  password_hash: string | null;
  name: string;
  last_name: string | null;
  nickname: string | null;
  avatar_url: string | null;
  google_id: string | null;
  vk_id: string | null;
  telegram_id: string | null;
  role: UserRole;
  created_at: Date;
  updated_at: Date;
}

export interface UserProfilePatch {
  name?: string;
  lastName?: string | null;
  nickname?: string | null;
  avatarUrl?: string | null;
}

export type SocialProvider = 'google' | 'vk' | 'telegram';

export const SOCIAL_ID_COLUMNS: Record<SocialProvider, 'google_id' | 'vk_id' | 'telegram_id'> = {
  google: 'google_id',
  vk: 'vk_id',
  telegram: 'telegram_id',
};
