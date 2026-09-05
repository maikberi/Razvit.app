import '../models/exercise.dart';
import '../models/workout.dart';
import 'mock_exercises.dart';

WorkoutDay _pushDay() => WorkoutDay(
      id: 'push_day',
      title: 'Push Day 💪',
      exercises: [
        ProgramExercise(exercise: exerciseById('seated_barbell_press'), sets: 4, repsLabel: '8–10', weightKg: 40, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('bench_press'), sets: 4, repsLabel: '8–10', weightKg: 100, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('incline_dumbbell_press'), sets: 3, repsLabel: '10–12', weightKg: 32, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('dumbbell_fly'), sets: 3, repsLabel: '12–15', weightKg: 12, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('overhead_press'), sets: 3, repsLabel: '8–10', weightKg: 50, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('lateral_raise'), sets: 3, repsLabel: '12–15', weightKg: 10, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('triceps_pushdown'), sets: 3, repsLabel: '12–15', weightKg: 25, restSeconds: 60),
      ],
    );

WorkoutDay _pullDay() => WorkoutDay(
      id: 'pull_day',
      title: 'Pull Day',
      exercises: [
        ProgramExercise(exercise: exerciseById('deadlift'), sets: 4, repsLabel: '6–8', weightKg: 120, restSeconds: 120),
        ProgramExercise(exercise: exerciseById('pull_up'), sets: 4, repsLabel: '8–10', weightKg: 0, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('bent_over_row'), sets: 3, repsLabel: '8–10', weightKg: 70, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('lat_pulldown'), sets: 3, repsLabel: '10–12', weightKg: 55, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('barbell_curl'), sets: 3, repsLabel: '10–12', weightKg: 30, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('dumbbell_curl'), sets: 3, repsLabel: '10–12', weightKg: 14, restSeconds: 60),
      ],
    );

WorkoutDay _legDay() => WorkoutDay(
      id: 'leg_day',
      title: 'Leg Day',
      exercises: [
        ProgramExercise(exercise: exerciseById('squat'), sets: 4, repsLabel: '6–8', weightKg: 100, restSeconds: 120),
        ProgramExercise(exercise: exerciseById('romanian_deadlift'), sets: 3, repsLabel: '8–10', weightKg: 80, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('leg_press'), sets: 3, repsLabel: '10–12', weightKg: 160, restSeconds: 90),
        ProgramExercise(exercise: exerciseById('lunges'), sets: 3, repsLabel: '10–12', weightKg: 16, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('plank'), sets: 3, repsLabel: '45–60 сек', weightKg: 0, restSeconds: 45),
      ],
    );

WorkoutDay _homeDay() => WorkoutDay(
      id: 'home_day',
      title: 'Домашняя тренировка',
      exercises: [
        ProgramExercise(exercise: exerciseById('dips'), sets: 3, repsLabel: '8–12', weightKg: 0, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('pull_up'), sets: 3, repsLabel: '5–8', weightKg: 0, restSeconds: 75),
        ProgramExercise(exercise: exerciseById('lunges'), sets: 3, repsLabel: '12–15', weightKg: 10, restSeconds: 60),
        ProgramExercise(exercise: exerciseById('plank'), sets: 3, repsLabel: '40–60 сек', weightKg: 0, restSeconds: 45),
        ProgramExercise(exercise: exerciseById('burpees'), sets: 3, repsLabel: '10–15', weightKg: 0, restSeconds: 60),
      ],
    );

/// Программы тренировок пользователя (мок-данные для MVP).
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
    id: 'cutting_pro',
    title: 'Сушка PRO',
    goal: ProgramGoal.loss,
    level: ProgramLevel.intermediate,
    totalWeeks: 6,
    currentWeek: 2,
    trainingDays: const [1, 3, 5],
    days: [_pushDay(), _legDay()],
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
final Map<String, List<ExerciseHistoryEntry>> mockExerciseHistory = {
  'bench_press': [
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 180)), weightKg: 70, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 150)), weightKg: 75, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 120)), weightKg: 80, reps: 10),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 90)), weightKg: 85, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 60)), weightKg: 90, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 30)), weightKg: 95, reps: 10),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 14)), weightKg: 100, reps: 8),
    ExerciseHistoryEntry(
      date: DateTime.now(),
      weightKg: 100,
      reps: 10,
      isPersonalRecord: true,
    ),
  ],
  'squat': [
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 150)), weightKg: 100, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 90)), weightKg: 130, reps: 8),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 45)), weightKg: 150, reps: 6),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 10)), weightKg: 160, reps: 6, isPersonalRecord: true),
  ],
  'deadlift': [
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 160)), weightKg: 120, reps: 6),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 100)), weightKg: 150, reps: 6),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 40)), weightKg: 170, reps: 5),
    ExerciseHistoryEntry(date: DateTime.now().subtract(const Duration(days: 5)), weightKg: 180, reps: 5, isPersonalRecord: true),
  ],
};

final List<PersonalRecord> mockPersonalRecords = [
  PersonalRecord(exerciseName: 'Жим лёжа', weightKg: 120, date: DateTime.now().subtract(const Duration(days: 3))),
  PersonalRecord(exerciseName: 'Приседания', weightKg: 160, date: DateTime.now().subtract(const Duration(days: 10))),
  PersonalRecord(exerciseName: 'Становая тяга', weightKg: 180, date: DateTime.now().subtract(const Duration(days: 5))),
];
