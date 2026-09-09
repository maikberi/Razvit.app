export interface UserRow {
  id: string;
  email: string;
  password_hash: string | null;
  name: string;
  google_id: string | null;
  created_at: Date;
  updated_at: Date;
}
