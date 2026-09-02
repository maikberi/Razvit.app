import 'exercise.dart';

enum SessionStatus { done, planned, missed }

/// Один зафиксированный подход во время тренировки.
class SetLog {
  const SetLog({
    required this.weightKg,
    required this.reps,
    this.completed = true,
  });

  final double weightKg;
  final int reps;
  final bool completed;

  double get volume => weightKg * reps;
}

/// Выполненные (или запланированные) подходы по одному упражнению
/// в рамках конкретной тренировки.
class ExerciseLog {
  const ExerciseLog({
    required this.exercise,
    required this.sets,
    this.comment,
  });

  final Exercise exercise;
  final List<SetLog> sets;
  final String? comment;

  double get volume => sets.fold(0, (sum, s) => sum + s.volume);
}

/// Тренировка, зафиксированная в истории (для календаря/статистики).
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.date,
    required this.title,
    required this.status,
    this.durationMinutes = 0,
    this.calories = 0,
    this.exerciseLogs = const [],
  });

  final String id;
  final DateTime date;
  final String title;
  final SessionStatus status;
  final int durationMinutes;
  final int calories;
  final List<ExerciseLog> exerciseLogs;

  double get volumeKg => exerciseLogs.fold(0, (sum, e) => sum + e.volume);
  int get totalSets => exerciseLogs.fold(0, (sum, e) => sum + e.sets.length);
  int get totalReps =>
      exerciseLogs.fold(0, (sum, e) => sum + e.sets.fold(0, (s, set) => s + set.reps));
}
