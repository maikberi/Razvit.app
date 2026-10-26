import { ProgressRepository } from './progress.repository';
import { WeightEntryRow } from './progress.model';

export class WeightEntryNotFoundError extends Error {
  constructor() {
    super('Weight entry not found');
    this.name = 'WeightEntryNotFoundError';
  }
}

export class ProgressService {
  constructor(private readonly repo: ProgressRepository) {}

  addWeightEntry(userId: string, weightKg: number, loggedAt?: Date): Promise<WeightEntryRow> {
    return this.repo.addWeightEntry(userId, weightKg, loggedAt);
  }

  listWeightEntries(userId: string): Promise<WeightEntryRow[]> {
    return this.repo.listWeightEntries(userId);
  }

  async deleteWeightEntry(userId: string, id: string): Promise<void> {
    const entry = await this.repo.findWeightEntry(userId, id);
    if (!entry) throw new WeightEntryNotFoundError();
    await this.repo.deleteWeightEntry(userId, id);
  }
}
