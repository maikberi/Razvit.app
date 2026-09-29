import { ExerciseRepository } from '../exercise/exercise.repository';
import { ExerciseRow, MuscleGroup } from '../exercise/exercise.model';
import { NutritionGoal } from '../nutrition/nutritionProfile.model';
import { NutritionProfileRepository } from '../nutrition/nutritionProfile.repository';
import { ProgramDayJson, ProgramGoal, WorkoutProgramRow } from './workout.model';
import { CreateProgramBody } from './workout.validation';
import { CompleteWorkoutProfile, Duration, Experience, WorkoutProfileRow } from './workoutProfile.model';
import { WorkoutProfileRepository } from './workoutProfile.repository';
import { WorkoutRepository } from './workout.repository';

export class IncompleteWorkoutProfileError extends Error {
  constructor(public readonly missingFields: string[]) {
    super(`Workout profile is incomplete: missing ${missingFields.join(', ')}`);
    this.name = 'IncompleteWorkoutProfileError';
  }
}

// goal (nutrition_profiles, 6 значений — тот же выбор из анкеты онбординга,
// см. workoutProgramGenerator рядом) -> goal самой программы
// (workout_programs, 5 значений). endurance не имеет точного соответствия
// ни одному из mass/loss/strength/definition/maintenance — ближе всего
// maintenance (это скорее про общую кондицию, чем про набор/сброс массы
// или силовые показатели).
const PROGRAM_GOAL: Record<NutritionGoal, ProgramGoal> = {
  lose_weight: 'loss',
  gain_muscle: 'mass',
  get_stronger: 'strength',
  improve_shape: 'definition',
  endurance: 'maintenance',
  maintain: 'maintenance',
};

const GOAL_TITLE: Record<NutritionGoal, string> = {
  lose_weight: 'Похудение',
  gain_muscle: 'Набор массы',
  get_stronger: 'Сила',
  improve_shape: 'Рельеф',
  endurance: 'Выносливость',
  maintain: 'Поддержание формы',
};

// Подходы/повторы/отдых по цели — типичные для похудения (много повторов,
// короткий отдых), силы (мало повторов, длинный отдых на восстановление
// между тяжёлыми подходами) и т.д. weightKg намеренно всегда 0 — реальный
// рабочий вес пользователь сам вводит/подстраивает во время тренировки
// (см. workout_session_screen.dart), генератор не может его угадать.
const SCHEME: Record<NutritionGoal, { sets: number; repsLabel: string; restSeconds: number }> = {
  lose_weight: { sets: 3, repsLabel: '15-20', restSeconds: 45 },
  gain_muscle: { sets: 4, repsLabel: '8-12', restSeconds: 75 },
  get_stronger: { sets: 5, repsLabel: '4-6', restSeconds: 150 },
  improve_shape: { sets: 3, repsLabel: '12-15', restSeconds: 60 },
  endurance: { sets: 3, repsLabel: '15-20', restSeconds: 30 },
  maintain: { sets: 3, repsLabel: '10-12', restSeconds: 60 },
};

// Сколько упражнений в день — по тому, сколько времени пользователь готов
// тратить на тренировку (WorkoutDuration в онбординге).
const EXERCISES_PER_DAY: Record<Duration, number> = {
  short: 4,
  medium: 5,
  long: 6,
  extended: 7,
  veryLong: 8,
};

// HomeEquipment (имена значений во Flutter-энаме) -> строки equipment в
// таблице exercises (свободный русский текст, см. миграцию 018). "Своё
// тело" не привязано ни к одному конкретному пункту онбординга — это
// единственное, что доступно всегда, независимо от выбора пользователя.
const BODYWEIGHT = 'Своё тело';
const EQUIPMENT_MAP: Record<string, string[]> = {
  dumbbells: ['Гантели'],
  barbell: ['Штанга', 'Машина Смита'],
  bands: ['Резинка'],
  pullUpBar: [BODYWEIGHT],
  mat: [BODYWEIGHT],
  other: [],
  none: [],
};

const ALL_EQUIPMENT = [
  BODYWEIGHT,
  'Гантели',
  'Штанга',
  'Блок (кроссовер)',
  'Рычажный тренажёр',
  'Резинка',
  'Машина Смита',
  'Тренажёр (сани)',
  'Тренажёр',
];

type DayType = 'full' | 'upper' | 'lower' | 'push' | 'pull' | 'legs';

const DAY_MUSCLES: Record<DayType, MuscleGroup[]> = {
  full: ['chest', 'back', 'legs', 'shoulders', 'arms', 'abs'],
  upper: ['chest', 'back', 'shoulders', 'arms'],
  lower: ['legs', 'abs'],
  push: ['chest', 'shoulders', 'arms'],
  pull: ['back', 'arms'],
  legs: ['legs', 'abs'],
};

const DAY_TITLE: Record<DayType, string> = {
  full: 'Всё тело',
  upper: 'Верх тела',
  lower: 'Низ тела',
  push: 'Жимовые (грудь, плечи, трицепс)',
  pull: 'Тяговые (спина, бицепс)',
  legs: 'Ноги и пресс',
};

// Сплит по числу тренировок в неделю (онбординг предлагает 2-6, но функция
// не падает и на крайних значениях вне этого диапазона).
function splitForDays(n: number): DayType[] {
  if (n <= 1) return ['full'];
  if (n === 2) return ['full', 'full'];
  if (n === 3) return ['full', 'full', 'full'];
  if (n === 4) return ['upper', 'lower', 'upper', 'lower'];
  if (n === 5) return ['push', 'pull', 'legs', 'upper', 'lower'];
  const pplRepeated: DayType[] = ['push', 'pull', 'legs', 'push', 'pull', 'legs'];
  return pplRepeated.slice(0, Math.min(n, 6));
}

// Дни недели (1=Пн..7=Вс), равномерно разнесённые под нужное количество
// тренировок — чтобы между тренировками, где возможно, был день отдыха.
const WEEKDAY_SPREAD: Record<number, number[]> = {
  1: [1],
  2: [1, 4],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 4, 5],
  6: [1, 2, 3, 4, 5, 6],
  7: [1, 2, 3, 4, 5, 6, 7],
};

/**
 * Workout Program Generator — по духу тот же pipeline, что и
 * NutritionTargetService: Profile -> Split -> Exercise pool -> Program, и
 * сразу сохраняет результат (POST /workout-programs использует тот же
 * WorkoutRepository, что и ручное создание программы в
 * create_program_screen.dart — генератор просто строит тело запроса сам).
 */
export class WorkoutProgramGenerator {
  constructor(
    private readonly workoutProfiles: WorkoutProfileRepository,
    private readonly nutritionProfiles: NutritionProfileRepository,
    private readonly exercises: ExerciseRepository,
    private readonly workouts: WorkoutRepository,
  ) {}

  async generate(userId: string): Promise<WorkoutProgramRow> {
    const profile = this.toCompleteProfile(await this.workoutProfiles.find(userId));
    const nutritionRow = await this.nutritionProfiles.find(userId);
    const goal = nutritionRow?.goal;
    if (!goal) throw new IncompleteWorkoutProfileError(['goal']);

    const equipmentPool = this.resolveEquipment(profile);
    const dayTypes = splitForDays(profile.workoutsPerWeek);
    const exercisesPerDay = EXERCISES_PER_DAY[profile.duration];
    const scheme = SCHEME[goal];

    const used = new Set<string>();
    const days: ProgramDayJson[] = [];
    for (let i = 0; i < dayTypes.length; i++) {
      const dayType = dayTypes[i];
      const picked = await this.pickExercisesForDay(DAY_MUSCLES[dayType], profile.experience, equipmentPool, exercisesPerDay, used);
      days.push({
        id: `day_${i + 1}`,
        title: this.dayTitle(dayTypes, i),
        exercises: picked.map((ex) => ({
          exerciseId: ex.id,
          exerciseName: ex.name,
          sets: scheme.sets,
          repsLabel: scheme.repsLabel,
          weightKg: 0,
          restSeconds: scheme.restSeconds,
        })),
      });
    }

    const body: CreateProgramBody = {
      title: `Твоя программа: ${GOAL_TITLE[goal]}`,
      goal: PROGRAM_GOAL[goal],
      level: profile.experience,
      totalWeeks: 8,
      trainingDays: WEEKDAY_SPREAD[profile.workoutsPerWeek] ?? WEEKDAY_SPREAD[3],
      days,
    };
    return this.workouts.createProgram(userId, body);
  }

  private toCompleteProfile(row: WorkoutProfileRow | null): CompleteWorkoutProfile {
    const missing: string[] = [];
    if (!row?.experience) missing.push('experience');
    if (!row?.place) missing.push('place');
    if (!row?.workouts_per_week) missing.push('workoutsPerWeek');
    if (!row?.duration) missing.push('duration');
    if (missing.length > 0) throw new IncompleteWorkoutProfileError(missing);
    return {
      experience: row!.experience!,
      place: row!.place!,
      equipment: row!.equipment ?? [],
      workoutsPerWeek: row!.workouts_per_week!,
      duration: row!.duration!,
    };
  }

  private resolveEquipment(profile: CompleteWorkoutProfile): string[] {
    if (profile.place === 'gym') return ALL_EQUIPMENT;
    if (profile.place === 'outdoor') return [BODYWEIGHT, 'Резинка'];

    const set = new Set<string>([BODYWEIGHT]);
    for (const item of profile.equipment) {
      for (const mapped of EQUIPMENT_MAP[item] ?? []) set.add(mapped);
    }
    return [...set];
  }

  private dayTitle(dayTypes: DayType[], index: number): string {
    const dayType = dayTypes[index];
    const occurrencesTotal = dayTypes.filter((d) => d === dayType).length;
    if (occurrencesTotal <= 1) return DAY_TITLE[dayType];
    const occurrence = dayTypes.slice(0, index + 1).filter((d) => d === dayType).length;
    return `${DAY_TITLE[dayType]} ${String.fromCharCode(64 + occurrence)}`; // A, B, C...
  }

  private async pickExercisesForDay(
    muscleGroups: MuscleGroup[],
    difficulty: Experience,
    equipmentPool: string[],
    count: number,
    used: Set<string>,
  ): Promise<ExerciseRow[]> {
    const picked: ExerciseRow[] = [];
    const perGroup = Math.max(1, Math.ceil(count / muscleGroups.length));

    for (const group of muscleGroups) {
      if (picked.length >= count) break;
      const candidates = await this.candidatesFor(group, difficulty, equipmentPool);
      if (candidates.length === 0) continue;
      const fresh = candidates.filter((c) => !used.has(c.id));
      // Если под эту группу мышц весь пул уже разобран в предыдущие дни —
      // лучше повторить упражнение, чем оставить группу вообще без него.
      const pool = fresh.length > 0 ? fresh : candidates;
      for (const ex of pool.slice(0, Math.min(perGroup, count - picked.length))) {
        picked.push(ex);
        used.add(ex.id);
      }
    }

    // Совсем крайний случай (нет ни одного подходящего упражнения ни под
    // одну из групп дня, например пустая тестовая БД) — день не должен
    // остаться без единого упражнения (createProgramSchema требует минимум
    // одно), поэтому последний фолбэк — вообще без фильтров.
    if (picked.length === 0) {
      const fallback = await this.exercises.search({ muscleGroup: muscleGroups[0], page: 1, perPage: 1 });
      if (fallback.items.length > 0) picked.push(fallback.items[0]);
    }
    return picked;
  }

  private async candidatesFor(group: MuscleGroup, difficulty: Experience, equipmentPool: string[]): Promise<ExerciseRow[]> {
    const exact = await this.exercises.search({
      muscleGroup: group,
      difficulty,
      equipmentIn: equipmentPool,
      page: 1,
      perPage: 20,
    });
    if (exact.items.length > 0) return exact.items;

    // Фолбэк 1: без ограничения по сложности — нехватка именно
    // подходящих под уровень пользователя упражнений для этой группы мышц.
    const anyDifficulty = await this.exercises.search({ muscleGroup: group, equipmentIn: equipmentPool, page: 1, perPage: 20 });
    if (anyDifficulty.items.length > 0) return anyDifficulty.items;

    // Фолбэк 2: без ограничения по оборудованию — лучше дать упражнение не
    // под то оборудование, что выбрал пользователь, чем не дать вообще
    // ничего для этой группы мышц (тонкий пул под некоторое оборудование,
    // см. комментарий в exercise seed про малое число тренажёрных/блочных
    // упражнений).
    const anyEquipment = await this.exercises.search({ muscleGroup: group, page: 1, perPage: 20 });
    return anyEquipment.items;
  }
}
