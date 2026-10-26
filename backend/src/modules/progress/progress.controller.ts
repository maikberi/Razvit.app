import { asyncHandler } from '../../utils/asyncHandler';
import { ProgressService } from './progress.service';
import { serializeWeightEntry } from './progress.serializer';
import { AddWeightEntryBody } from './progress.validation';

export class ProgressController {
  constructor(private readonly service: ProgressService) {}

  /** POST /weight-entries */
  addWeightEntry = asyncHandler(async (req, res) => {
    const body = req.validatedBody as AddWeightEntryBody;
    const entry = await this.service.addWeightEntry(req.userId as string, body.weightKg, body.loggedAt);
    res.status(201).json({ data: serializeWeightEntry(entry) });
  });

  /** GET /weight-entries */
  listWeightEntries = asyncHandler(async (req, res) => {
    const entries = await this.service.listWeightEntries(req.userId as string);
    res.status(200).json({ data: entries.map(serializeWeightEntry) });
  });

  /** DELETE /weight-entries/:id */
  deleteWeightEntry = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    await this.service.deleteWeightEntry(req.userId as string, id);
    res.status(204).send();
  });
}
