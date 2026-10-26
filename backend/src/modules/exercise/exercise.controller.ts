import { asyncHandler } from '../../utils/asyncHandler';
import { ExerciseService } from './exercise.service';
import { serializeExercise, serializePage } from './exercise.serializer';
import { SearchQuery } from './exercise.validation';

export class ExerciseController {
  constructor(private readonly service: ExerciseService) {}

  /** GET /exercises — каталог с фильтрами/поиском/пагинацией. Публичный, как /foods. */
  list = asyncHandler(async (req, res) => {
    const q = req.validatedQuery as SearchQuery;
    const page = await this.service.search({
      query: q.q,
      muscleGroup: q.muscleGroup,
      equipment: q.equipment,
      difficulty: q.difficulty,
      page: q.page,
      perPage: q.perPage,
    });
    res.status(200).json(serializePage(page));
  });

  /** GET /exercises/:id */
  getById = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    const exercise = await this.service.getById(id);
    res.status(200).json({ data: serializeExercise(exercise) });
  });

  /** GET /exercises/favorites — избранные упражнения текущего пользователя. */
  listFavorites = asyncHandler(async (req, res) => {
    const exercises = await this.service.listFavorites(req.userId as string);
    res.status(200).json({ data: exercises.map((e) => serializeExercise(e, true)) });
  });

  /** POST /exercises/:id/favorite */
  addFavorite = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    await this.service.setFavorite(req.userId as string, id, true);
    res.status(204).send();
  });

  /** DELETE /exercises/:id/favorite */
  removeFavorite = asyncHandler(async (req, res) => {
    const { id } = req.validatedParams as { id: string };
    await this.service.setFavorite(req.userId as string, id, false);
    res.status(204).send();
  });
}
