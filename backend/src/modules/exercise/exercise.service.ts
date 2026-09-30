import { ExerciseRepository } from './exercise.repository';
import { ExerciseRow, ExerciseSearchParams, PagedResult } from './exercise.model';

export class ExerciseNotFoundError extends Error {
  constructor() {
    super('Exercise not found');
    this.name = 'ExerciseNotFoundError';
  }
}

export class ExerciseService {
  constructor(private readonly repo: ExerciseRepository) {}

  async getById(id: string): Promise<ExerciseRow> {
    const exercise = await this.repo.findById(id);
    if (!exercise) throw new ExerciseNotFoundError();
    return exercise;
  }

  async search(params: ExerciseSearchParams): Promise<PagedResult<ExerciseRow>> {
    return this.repo.search(params);
  }

  async setFavorite(userId: string, exerciseId: string, favorite: boolean): Promise<void> {
    // Проверяем существование, чтобы избранным нельзя было отметить
    // несуществующий id (иначе получили бы "тихий" 200 без эффекта).
    await this.getById(exerciseId);
    if (favorite) {
      await this.repo.addFavorite(userId, exerciseId);
    } else {
      await this.repo.removeFavorite(userId, exerciseId);
    }
  }

  async listFavorites(userId: string): Promise<ExerciseRow[]> {
    const ids = await this.repo.listFavoriteIds(userId);
    return this.repo.findByIds(ids);
  }
}
