export interface WeightEntryRow {
  id: string;
  user_id: string;
  weight_kg: string; // NUMERIC приходит из pg строкой
  logged_at: Date;
}
