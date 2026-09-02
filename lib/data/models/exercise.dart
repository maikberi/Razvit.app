enum MuscleGroup { chest, back, legs, shoulders, arms, abs, cardio }

extension MuscleGroupX on MuscleGroup {
  String get label => switch (this) {
        MuscleGroup.chest => 'Грудь',
        MuscleGroup.back => 'Спина',
        MuscleGroup.legs => 'Ноги',
        MuscleGroup.shoulders => 'Плечи',
        MuscleGroup.arms => 'Руки',
        MuscleGroup.abs => 'Пресс',
        MuscleGroup.cardio => 'Кардио',
      };
}

enum ExerciseDifficulty { beginner, intermediate, advanced }

extension ExerciseDifficultyX on ExerciseDifficulty {
  String get label => switch (this) {
        ExerciseDifficulty.beginner => 'Начальный',
        ExerciseDifficulty.intermediate => 'Средний',
        ExerciseDifficulty.advanced => 'Продвинутый',
      };
}

/// Упражнение из библиотеки RAZVIT.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscle,
    this.secondaryMuscles = const [],
    required this.equipment,
    required this.difficulty,
    this.instructions = const [],
    this.mistakes = const [],
    this.tips = const [],
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final MuscleGroup primaryMuscle;
  final List<MuscleGroup> secondaryMuscles;
  final String equipment;
  final ExerciseDifficulty difficulty;
  final List<String> instructions;
  final List<String> mistakes;
  final List<String> tips;
  final bool isFavorite;
}

/// Одна запись выполнения подхода в истории конкретного упражнения.
class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    required this.date,
    required this.weightKg,
    required this.reps,
    this.isPersonalRecord = false,
  });

  final DateTime date;
  final double weightKg;
  final int reps;
  final bool isPersonalRecord;

  double get volume => weightKg * reps;
}

class PersonalRecord {
  const PersonalRecord({
    required this.exerciseName,
    required this.weightKg,
    required this.date,
  });

  final String exerciseName;
  final double weightKg;
  final DateTime date;
}
