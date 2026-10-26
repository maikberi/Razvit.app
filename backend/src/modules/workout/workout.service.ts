import { WorkoutRepository } from './workout.repository';
import { WorkoutProgramRow, WorkoutSessionRow } from './workout.model';
import { CreateProgramBody, CreateSessionBody } from './workout.validation';

export class WorkoutProgramNotFoundError extends Error {
  constructor() {
    super('Workout program not found');
    this.name = 'WorkoutProgramNotFoundError';
  }
}

export class WorkoutService {
  constructor(private readonly repo: WorkoutRepository) {}

  createProgram(userId: string, input: CreateProgramBody): Promise<WorkoutProgramRow> {
    return this.repo.createProgram(userId, input);
  }

  listPrograms(userId: string): Promise<WorkoutProgramRow[]> {
    return this.repo.listPrograms(userId);
  }

  async deleteProgram(userId: string, id: string): Promise<void> {
    const program = await this.repo.findProgram(userId, id);
    if (!program) throw new WorkoutProgramNotFoundError();
    await this.repo.deleteProgram(userId, id);
  }

  async createSession(userId: string, input: CreateSessionBody): Promise<WorkoutSessionRow> {
    // Если сессия ссылается на программу, созданную пользователем —
    // убеждаемся, что программа реально его и существует, а не чужой UUID.
    if (input.programId) {
      const program = await this.repo.findProgram(userId, input.programId);
      if (!program) throw new WorkoutProgramNotFoundError();
    }
    return this.repo.createSession(userId, input);
  }

  listSessions(userId: string): Promise<WorkoutSessionRow[]> {
    return this.repo.listSessions(userId);
  }
}
