import '../models/exercise.dart';
import '../models/workout.dart';
import 'mock_exercises.dart';

// Все программы ниже собраны из реального каталога 100 упражнений
// (mock_exercises.dart) с настоящими GIF-анимациями — не абстрактные
// заглушки, как раньше, а рабочие тренировки, которые можно открыть
// и пройти по шагам с наглядной техникой на каждом подходе.

WorkoutDay _pushDay() => WorkoutDay(
      id: 'push_day',
      title: 'Грудь, плечи, трицепс',
      exercises: [
        ProgramExercise(exercise: exerciseById('barbell-bench-press'), sets: 4, repsLabel: '8–10', weightKg: 60, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('barbell-incline-bench-press'), sets: 3, repsLabel: '8–10', weightKg: 45, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('dumbbell-seated-shoulder-press'), sets: 3, repsLabel: '10–12', weightKg: 16, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('dumbbell-lateral-raise'), sets: 3, repsLabel: '12–15', weightKg: 8, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('cable-triceps-pushdown-v-bar'), sets: 3, repsLabel: '12–15', weightKg: 25, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('push-up'), sets: 3, repsLabel: '15–20', weightKg: 0, restSeconds: 60),
      ],
    );

WorkoutDay _pullDay() => WorkoutDay(
      id: 'pull_day',
      title: 'Спина, бицепс',
      exercises: [
        ProgramExercise(exercise: exerciseById('barbell-deadlift'), sets: 4, repsLabel: '5–6', weightKg: 90, restSeconds: 120),
        ProgramExercise(exercise: exerciseById('barbell-bent-over-row'), sets: 4, repsLabel: '8–10', weightKg: 50, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('pull-up'), sets: 4, repsLabel: '6–10', weightKg: 0, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('cable-bar-lateral-pulldown'), sets: 3, repsLabel: '10–12', weightKg: 45, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('barbell-curl'), sets: 3, repsLabel: '10–12', weightKg: 25, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('dumbbell-alternate-seated-hammer-curl'), sets: 3, repsLabel: '10–12', weightKg: 10, restSeconds: 60),
      ],
    );

WorkoutDay _legDay() => WorkoutDay(
      id: 'leg_day',
      title: 'Ноги, ягодицы',
      exercises: [
        ProgramExercise(exercise: exerciseById('barbell-full-squat'), sets: 4, repsLabel: '6–8', weightKg: 70, restSeconds: 120),
        ProgramExercise(exercise: exerciseById('barbell-romanian-deadlift'), sets: 3, repsLabel: '8–10', weightKg: 55, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('dumbbell-lunge'), sets: 3, repsLabel: '10–12', weightKg: 14, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('lever-leg-extension'), sets: 3, repsLabel: '12–15', weightKg: 35, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('bodyweight-standing-calf-raise'), sets: 4, repsLabel: '15–20', weightKg: 0, restSeconds: 45),
        ProgramExercise(exercise: exerciseById('front-plank-with-twist'), sets: 3, repsLabel: '30–45 сек', weightKg: 0, restSeconds: 45),
      ],
    );

WorkoutDay _homeDay() => WorkoutDay(
      id: 'home_day',
      title: 'Домашняя тренировка',
      exercises: [
        ProgramExercise(exercise: exerciseById('push-up'), sets: 3, repsLabel: '12–15', weightKg: 0, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('dumbbell-goblet-squat'), sets: 3, repsLabel: '12–15', weightKg: 10, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('assisted-pull-up'), sets: 3, repsLabel: '6–10', weightKg: 0, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('dead-bug'), sets: 3, repsLabel: '10–12', weightKg: 0, restSeconds: 45),
        ProgramExercise(exercise: exerciseById('mountain-climber'), sets: 3, repsLabel: '30–40 сек', weightKg: 0, restSeconds: 45),
        ProgramExercise(exercise: exerciseById('burpee'), sets: 3, repsLabel: '8–12', weightKg: 0, restSeconds: 60),
      ],
    );

WorkoutDay _fullBodyDay() => WorkoutDay(
      id: 'full_body_day',
      title: 'Всё тело',
      exercises: [
        ProgramExercise(exercise: exerciseById('barbell-full-squat'), sets: 3, repsLabel: '8–10', weightKg: 40, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('dumbbell-bench-press'), sets: 3, repsLabel: '10–12', weightKg: 14, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('dumbbell-bent-over-row'), sets: 3, repsLabel: '10–12', weightKg: 14, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('barbell-glute-bridge'), sets: 3, repsLabel: '12–15', weightKg: 30, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('jump-rope'), sets: 3, repsLabel: '60 сек', weightKg: 0, restSeconds: 45),
      ],
    );

/// Программы тренировок пользователя (мок-данные для MVP, поверх реального
/// каталога упражнений с GIF).
final List<WorkoutProgram> mockPrograms = [
  WorkoutProgram(
    id: 'ppl',
    title: 'Push Pull Legs',
    goal: ProgramGoal.mass,
    level: ProgramLevel.advanced,
    totalWeeks: 8,
    currentWeek: 3,
    trainingDays: const [1, 2, 3, 5, 6],
    days: [_pushDay(), _pullDay(), _legDay()],
    imageSeed: 0,
  ),
  WorkoutProgram(
    id: 'fullbody_beginner',
    title: 'Fullbody для начинающих',
    goal: ProgramGoal.maintenance,
    level: ProgramLevel.beginner,
    totalWeeks: 6,
    currentWeek: 1,
    trainingDays: const [1, 3, 5],
    days: [_fullBodyDay()],
    imageSeed: 1,
  ),
  WorkoutProgram(
    id: 'mass_gain',
    title: 'Набор массы',
    goal: ProgramGoal.mass,
    level: ProgramLevel.advanced,
    totalWeeks: 12,
    currentWeek: 5,
    trainingDays: const [1, 2, 4, 5],
    days: [_pushDay(), _pullDay(), _legDay()],
    imageSeed: 2,
  ),
  WorkoutProgram(
    id: 'home_program',
    title: 'Домашняя программа',
    goal: ProgramGoal.maintenance,
    level: ProgramLevel.beginner,
    totalWeeks: 4,
    currentWeek: 1,
    trainingDays: const [2, 4, 6],
    days: [_homeDay()],
    isCustom: true,
    imageSeed: 3,
  ),
];

WorkoutProgram get activeProgram => mockPrograms.first;
WorkoutDay get todayWorkout => activeProgram.days.first;

/// История подходов по упражнениям — движок для графиков прогресса.
/// Ключи — id из mockExercises (реальные упражнения с GIF).
final Map<String, List<ExerciseHistoryEntry>> mockExerciseHistory = {
  'barbell-bench-press': [
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 180)), weightKg: 50, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 150)), weightKg: 52.5, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 120)), weightKg: 55, reps: 10),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 90)), weightKg: 57.5, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 60)), weightKg: 60, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 30)), weightKg: 62.5, reps: 10),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 14)), weightKg: 65, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now(), weightKg: 65, reps: 10, isPersonalRecord: true),
  ],
  'barbell-full-squat': [
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 150)), weightKg: 60, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 90)), weightKg: 65, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 45)), weightKg: 70, reps: 6),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 10)), weightKg: 75, reps: 6, isPersonalRecord: true),
  ],
  'barbell-deadlift': [
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 160)), weightKg: 70, reps: 6),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 100)), weightKg: 80, reps: 6),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 40)), weightKg: 90, reps: 5),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 5)), weightKg: 95, reps: 5, isPersonalRecord: true),
  ],
};

final List<PersonalRecord> mockPersonalRecords = [
  PersonalRecord(exerciseName: 'Жим штанги лёжа', weightKg: 65, date: DateTime.now().subtract(const Duration(days: 3))),
  PersonalRecord(exerciseName: 'Приседания со штангой', weightKg: 75, date: DateTime.now().subtract(const Duration(days: 10))),
  PersonalRecord(exerciseName: 'Становая тяга со штангой', weightKg: 95, date: DateTime.now().subtract(const Duration(days: 5))),
];
