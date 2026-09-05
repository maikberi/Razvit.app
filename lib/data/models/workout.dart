import 'exercise.dart';

/// Плановые параметры упражнения внутри программы (не факт выполнения).
class ProgramExercise {
  const ProgramExercise({
    required this.exercise,
    required this.sets,
    required this.repsLabel,
    required this.weightKg,
    required this.restSeconds,
  });

  final Exercise exercise;
  final int sets;
  final String repsLabel; // например "8–10"
  final double weightKg;
  final int restSeconds;

  String get restLabel {
    final m = restSeconds ~/ 60;
    final s = restSeconds % 60;
    if (m == 0) return '$s сек';
    if (s == 0) return '$m мин';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Тренировочный день программы, например «Понедельник — Push Day».
class WorkoutDay {
  const WorkoutDay({
    required this.id,
    required this.title,
    required this.exercises,
  });

  final String id;
  final String title;
  final List<ProgramExercise> exercises;

  Duration get estimatedDuration {
    final workSeconds = exercises.fold<int>(0, (sum, e) => sum + e.sets * 45);
    final restSeconds = exercises.fold<int>(0, (sum, e) => sum + e.sets * e.restSeconds);
    return Duration(seconds: workSeconds + restSeconds);
  }

  double get estimatedVolumeKg =>
      exercises.fold(0, (sum, e) => sum + e.weightKg * e.sets * _avgReps(e.repsLabel));

  static int _avgReps(String label) {
    final parts = label.split('–').map((e) => int.tryParse(e.trim()) ?? 10).toList();
    if (parts.isEmpty) return 10;
    if (parts.length == 1) return parts.first;
    return ((parts.first + parts.last) / 2).round();
  }
}

enum ProgramGoal { mass, loss, strength, definition, maintenance }

extension ProgramGoalX on ProgramGoal {
  String get label => switch (this) {
        ProgramGoal.mass => 'Набор массы',
        ProgramGoal.loss => 'Похудение',
        ProgramGoal.strength => 'Сила',
        ProgramGoal.definition => 'Рельеф',
        ProgramGoal.maintenance => 'Поддержание формы',
      };
}

enum ProgramLevel { beginner, intermediate, advanced }

extension ProgramLevelX on ProgramLevel {
  String get label => switch (this) {
        ProgramLevel.beginner => 'Начальный',
        ProgramLevel.intermediate => 'Средний',
        ProgramLevel.advanced => 'Продвинутый',
      };
}

/// Тренировочная программа пользователя (несколько дней, недель).
class WorkoutProgram {
  const WorkoutProgram({
    required this.id,
    required this.title,
    required this.goal,
    required this.level,
    required this.totalWeeks,
    required this.currentWeek,
    required this.days,
    required this.trainingDays, // 1=Пн ... 7=Вс
    this.imageSeed = 0,
    this.isCustom = false,
  });

  final String id;
  final String title;
  final ProgramGoal goal;
  final ProgramLevel level;
  final int totalWeeks;
  final int currentWeek;
  final List<WorkoutDay> days;
  final List<int> trainingDays;
  final int imageSeed;
  final bool isCustom;

  double get progress => (currentWeek / totalWeeks).clamp(0, 1);
}
