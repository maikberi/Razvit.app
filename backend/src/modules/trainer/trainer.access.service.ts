import { TrainerRepository } from './trainer.repository';

/**
 * Тренер попытался обратиться к данным клиента, с которым у него нет
 * approved-связи (либо связи нет вообще, либо она pending/declined/revoked).
 * Единственная причина 403 во всём тренерском модуле.
 */
export class TrainerAccessDeniedError extends Error {
  constructor() {
    super('You do not have approved access to this client');
    this.name = 'TrainerAccessDeniedError';
  }
}

/**
 * Единственное место, которое решает "может ли этот тренер видеть/менять
 * данные этого клиента". КАЖДЫЙ backend-эндпоинт, где тренер обращается к
 * данным конкретного клиента, обязан вызвать assertApproved ПЕРЕД любым
 * чтением/записью — Flutter здесь никакой роли не играет и ему не доверяют
 * (см. SECURITY в постановке задачи ЭТАП 17).
 */
export class TrainerAccessService {
  constructor(private readonly repo: TrainerRepository) {}

  async assertApproved(trainerId: string, clientId: string): Promise<void> {
    const relation = await this.repo.findRelation(trainerId, clientId);
    if (!relation || relation.status !== 'approved') {
      throw new TrainerAccessDeniedError();
    }
  }
}
