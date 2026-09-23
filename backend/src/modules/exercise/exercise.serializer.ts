import { ExerciseRow, PagedResult } from './exercise.model';

/**
 * Форма ответа повторяет поля Flutter-модели Exercise (lib/data/models/exercise.dart):
 * primaryMuscle/secondaryMuscles — строковые значения enum MuscleGroup,
 * difficulty — значение enum ExerciseDifficulty. gifUrl — новое поле вместо
 * videoAsset/videoPosterAsset (те были путями к локальным ассетам).
 */
export interface ExerciseDTO {
  id: string;
  slug: string;
  name: string;
  primaryMuscle: string;
  secondaryMuscles: string[];
  equipment: string;
  difficulty: string;
  instructions: string[];
  gifUrl: string | null;
  thumbUrl: string | null;
  isFavorite: boolean;
}

export function serializeExercise(exercise: ExerciseRow, isFavorite = false): ExerciseDTO {
  return {
    id: exercise.id,
    slug: exercise.slug,
    name: exercise.name,
    primaryMuscle: exercise.muscle_group,
    secondaryMuscles: exercise.secondary_muscles,
    equipment: exercise.equipment,
    difficulty: exercise.difficulty,
    instructions: exercise.instructions,
    gifUrl: exercise.gif_url,
    thumbUrl: exercise.thumb_url,
    isFavorite,
  };
}

export function serializePage(page: PagedResult<ExerciseRow>, favoriteIds: Set<string> = new Set()) {
  return {
    data: page.items.map((e) => serializeExercise(e, favoriteIds.has(e.id))),
    meta: {
      page: page.page,
      perPage: page.perPage,
      total: page.total,
      totalPages: page.totalPages,
    },
  };
}
