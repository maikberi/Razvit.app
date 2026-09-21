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

ExerciseDifficulty _difficultyFromJson(String value) =>
    ExerciseDifficulty.values.asNameMap()[value] ?? ExerciseDifficulty.beginner;

MuscleGroup _muscleFromJson(String value) => MuscleGroup.values.asNameMap()[value] ?? MuscleGroup.cardio;

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
    this.videoAsset,
    this.videoPosterAsset,
    this.gifUrl,
    this.thumbUrl,
  });

  final String id;
  final String name;
  final MuscleGroup primaryMuscle;
  final List<MuscleGroup> secondaryMuscles;
  final String equipment;
  /// Путь к зацикленному демо-видео техники выполнения (если есть) — старые
  /// моковые упражнения программ/тренировок, локальный ассет.
  final String? videoAsset;
  /// Кадр-превью видео — показывается мгновенно, пока видео догружается.
  final String? videoPosterAsset;
  /// Анимация техники выполнения из библиотеки упражнений backend (GET
  /// /exercises) — предпочитается перед videoAsset, если задана.
  final String? gifUrl;
  /// Маленькое превью gifUrl — для строк списка каталога.
  final String? thumbUrl;
  final ExerciseDifficulty difficulty;
  final List<String> instructions;
  final List<String> mistakes;
  final List<String> tips;
  final bool isFavorite;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        primaryMuscle: _muscleFromJson(json['primaryMuscle'] as String),
        secondaryMuscles: (json['secondaryMuscles'] as List<dynamic>? ?? const [])
            .map((m) => _muscleFromJson(m as String))
            .toList(),
        equipment: json['equipment'] as String,
        difficulty: _difficultyFromJson(json['difficulty'] as String),
        instructions: (json['instructions'] as List<dynamic>? ?? const []).cast<String>(),
        gifUrl: json['gifUrl'] as String?,
        thumbUrl: json['thumbUrl'] as String?,
        isFavorite: json['isFavorite'] as bool? ?? false,
      );
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
