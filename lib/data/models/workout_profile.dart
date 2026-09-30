import 'user.dart';

/// Анкета онбординга (тренировочная часть) на backend — GET/PUT
/// /workout-profile. Все значения enum'ов (ExperienceLevel/TrainingPlace/
/// WorkoutDuration) сериализуются через .name один в один: backend
/// использует те же строки (beginner/intermediate/advanced,
/// gym/home/outdoor/mixed, short/medium/long/extended/veryLong), поэтому
/// отдельная apiValue-таблица не нужна — см. workoutProfile.model.ts.
class WorkoutProfile {
  const WorkoutProfile({
    this.experience,
    this.place,
    this.equipment = const [],
    this.workoutsPerWeek,
    this.duration,
  });

  final ExperienceLevel? experience;
  final TrainingPlace? place;
  final List<String> equipment;
  final int? workoutsPerWeek;
  final WorkoutDuration? duration;

  factory WorkoutProfile.fromJson(Map<String, dynamic> json) => WorkoutProfile(
        experience: ExperienceLevel.values.asNameMap()[json['experience'] as String? ?? ''],
        place: TrainingPlace.values.asNameMap()[json['place'] as String? ?? ''],
        equipment: (json['equipment'] as List<dynamic>? ?? const []).cast<String>(),
        workoutsPerWeek: (json['workoutsPerWeek'] as num?)?.toInt(),
        duration: WorkoutDuration.values.asNameMap()[json['duration'] as String? ?? ''],
      );
}
