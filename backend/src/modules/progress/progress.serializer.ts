import { WeightEntryRow } from './progress.model';

export interface WeightEntryDTO {
  id: string;
  weightKg: number;
  loggedAt: string;
}

export function serializeWeightEntry(row: WeightEntryRow): WeightEntryDTO {
  return {
    id: row.id,
    weightKg: Number(row.weight_kg),
    loggedAt: row.logged_at.toISOString(),
  };
}
