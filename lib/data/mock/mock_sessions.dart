import 'dart:math';

import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import 'mock_exercises.dart';
import 'mock_programs.dart';

List<ExerciseLog> _logsFor(WorkoutDay day, Random rnd) {
  return day.exercises.map((pe) {
    final baseReps = int.tryParse(pe.repsLabel.split('–').first) ?? 10;
    final sets = List.generate(pe.sets, (i) {
      final variance = rnd.nextInt(5) - 2;
      return SetLog(weightKg: pe.weightKg, reps: (baseReps + variance).clamp(4, 20));
    });
    return ExerciseLog(exercise: pe.exercise, sets: sets);
  }).toList();
}

/// Генерирует историю тренировок за последние [days] дней на основе
/// расписания активной программы — используется календарём и статистикой.
List<WorkoutSession> generateMockSessions({int days = 60}) {
  final rnd = Random(42);
  final program = activeProgram;
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  var dayIndex = 0;

  for (var offset = days; offset >= 0; offset--) {
    final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));
    final weekday = date.weekday; // 1=Пн..7=Вс
    if (!program.trainingDays.contains(weekday)) continue;

    final workoutDay = program.days[dayIndex % program.days.length];
    dayIndex++;

    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
    if (isFuture) {
      sessions.add(WorkoutSession(
        id: 'planned_${date.toIso8601String()}',
        date: date,
        title: workoutDay.title,
        status: SessionStatus.planned,
      ));
      continue;
    }

    final isToday = offset == 0;
    if (isToday) {
      continue; // сегодняшняя тренировка ещё не начата — обрабатывается отдельно
    }

    final missed = rnd.nextDouble() < 0.12;
    if (missed) {
      sessions.add(WorkoutSession(
        id: 'missed_${date.toIso8601String()}',
        date: date,
        title: workoutDay.title,
        status: SessionStatus.missed,
      ));
      continue;
    }

    final logs = _logsFor(workoutDay, rnd);
    final duration = 45 + rnd.nextInt(30);
    sessions.add(WorkoutSession(
      id: 'done_${date.toIso8601String()}',
      date: date,
      title: workoutDay.title,
      status: SessionStatus.done,
      durationMinutes: duration,
      calories: 380 + rnd.nextInt(220),
      exerciseLogs: logs,
    ));
  }

  return sessions;
}

final List<WorkoutSession> mockSessions = generateMockSessions();

WorkoutSession get lastCompletedSession =>
    mockSessions.lastWhere((s) => s.status == SessionStatus.done);

List<Exercise> get favoriteExercises =>
    mockExercises.where((e) => e.isFavorite).toList();
