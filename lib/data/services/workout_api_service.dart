import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../mock/mock_exercises.dart';
import '../models/exercise.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/workout_profile.dart';

/// Клиент сохранённых на backend программ и тренировок RAZVIT
/// (POST/GET /workout-programs, POST/GET /workout-sessions) — заменяет
/// прежнее in-memory состояние (customProgramsProvider/mockSessions),
/// которое терялось при перезапуске приложения.
class WorkoutApiService {
  WorkoutApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<WorkoutProgram> createProgram(WorkoutProgram program) async {
    final json = await _client.postJson('/api/v1/workout-programs', _programToJson(program));
    return _programFromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<WorkoutProgram>> listPrograms() async {
    final json = await _client.getJson('/api/v1/workout-programs');
    final data = (json['data'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(_programFromJson).toList();
  }

  Future<void> deleteProgram(String id) => _client.delete('/api/v1/workout-programs/${Uri.encodeComponent(id)}');

  Future<WorkoutProfile> getProfile() async {
    final json = await _client.getJson('/api/v1/workout-profile');
    return WorkoutProfile.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<WorkoutProfile> updateProfile({
    ExperienceLevel? experience,
    TrainingPlace? place,
    Set<HomeEquipment>? equipment,
    int? workoutsPerWeek,
    WorkoutDuration? duration,
  }) async {
    final json = await _client.putJson('/api/v1/workout-profile', {
      if (experience != null) 'experience': experience.name,
      if (place != null) 'place': place.name,
      if (equipment != null) 'equipment': equipment.map((e) => e.name).toList(),
      if (workoutsPerWeek != null) 'workoutsPerWeek': workoutsPerWeek,
      if (duration != null) 'duration': duration.name,
    });
    return WorkoutProfile.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Workout Program Generator на backend: анкета (этот сервис) + цель
  /// из nutrition-профиля -> сплит по дням -> подбор упражнений из
  /// реального каталога -> сохранённая программа (см.
  /// workoutProgramGenerator.service.ts). Требует, чтобы перед этим уже
  /// были сохранены и профиль тренировок (updateProfile выше), и goal в
  /// nutrition-профиле (NutritionApiService.updateProfile).
  Future<WorkoutProgram> generateProgram() async {
    final json = await _client.postJson('/api/v1/workout-programs/generate', const {});
    return _programFromJson(json['data'] as Map<String, dynamic>);
  }

  Future<WorkoutSession> createSession({
    String? programId,
    String? programDayId,
    required DateTime date,
    required String title,
    required SessionStatus status,
    required int durationMinutes,
    required int calories,
    required List<ExerciseLog> exerciseLogs,
  }) async {
    final json = await _client.postJson('/api/v1/workout-sessions', {
      if (programId != null) 'programId': programId,
      if (programDayId != null) 'programDayId': programDayId,
      'date': date.toUtc().toIso8601String(),
      'title': title,
      'status': status.name,
      'durationMinutes': durationMinutes,
      'calories': calories,
      'exerciseLogs': exerciseLogs.map(_exerciseLogToJson).toList(),
    });
    return _sessionFromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<WorkoutSession>> listSessions() async {
    final json = await _client.getJson('/api/v1/workout-sessions');
    final data = (json['data'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(_sessionFromJson).toList();
  }

  Map<String, dynamic> _programToJson(WorkoutProgram program) => {
        'title': program.title,
        'goal': program.goal.name,
        'level': program.level.name,
        'totalWeeks': program.totalWeeks,
        'trainingDays': program.trainingDays,
        'days': program.days.map(_dayToJson).toList(),
      };

  Map<String, dynamic> _dayToJson(WorkoutDay day) => {
        'id': day.id,
        'title': day.title,
        'exercises': day.exercises.map(_programExerciseToJson).toList(),
      };

  Map<String, dynamic> _programExerciseToJson(ProgramExercise e) => {
        'exerciseId': e.exercise.id,
        'exerciseName': e.exercise.name,
        'sets': e.sets,
        'repsLabel': e.repsLabel,
        'weightKg': e.weightKg,
        'restSeconds': e.restSeconds,
      };

  Map<String, dynamic> _exerciseLogToJson(ExerciseLog log) => {
        'exerciseId': log.exercise.id,
        'exerciseName': log.exercise.name,
        if (log.comment != null) 'comment': log.comment,
        'sets': log.sets
            .map((s) => {'weightKg': s.weightKg, 'reps': s.reps, 'completed': s.completed})
            .toList(),
      };

  WorkoutProgram _programFromJson(Map<String, dynamic> json) {
    final days = (json['days'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_dayFromJson)
        .toList();
    return WorkoutProgram(
      id: json['id'] as String,
      title: json['title'] as String,
      goal: _goalFromJson(json['goal'] as String),
      level: _levelFromJson(json['level'] as String),
      totalWeeks: (json['totalWeeks'] as num).toInt(),
      currentWeek: 1,
      trainingDays: (json['trainingDays'] as List<dynamic>? ?? const []).map((d) => (d as num).toInt()).toList(),
      isCustom: true,
      imageSeed: (json['id'] as String).hashCode,
      days: days,
    );
  }

  WorkoutDay _dayFromJson(Map<String, dynamic> json) => WorkoutDay(
        id: json['id'] as String,
        title: json['title'] as String,
        exercises: (json['exercises'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(_programExerciseFromJson)
            .toList(),
      );

  ProgramExercise _programExerciseFromJson(Map<String, dynamic> json) => ProgramExercise(
        exercise: _exerciseFromLog(json['exerciseId'] as String, json['exerciseName'] as String),
        sets: (json['sets'] as num).toInt(),
        repsLabel: json['repsLabel'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        restSeconds: (json['restSeconds'] as num).toInt(),
      );

  WorkoutSession _sessionFromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String).toLocal(),
        title: json['title'] as String,
        status: _statusFromJson(json['status'] as String),
        durationMinutes: (json['durationMinutes'] as num).toInt(),
        calories: (json['calories'] as num).toInt(),
        exerciseLogs: (json['exerciseLogs'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(_exerciseLogFromJson)
            .toList(),
      );

  ExerciseLog _exerciseLogFromJson(Map<String, dynamic> json) => ExerciseLog(
        exercise: _exerciseFromLog(json['exerciseId'] as String, json['exerciseName'] as String),
        comment: json['comment'] as String?,
        sets: (json['sets'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map((s) => SetLog(
                  weightKg: (s['weightKg'] as num).toDouble(),
                  reps: (s['reps'] as num).toInt(),
                  completed: s['completed'] as bool? ?? true,
                ))
            .toList(),
      );

  /// Упражнение по id из каталога, если он всё ещё там есть, иначе —
  /// облегчённая заглушка с реальным названием (сохранённым вместе с
  /// сессией) вместо "Упражнение не найдено": каталог мог измениться,
  /// а история тренировки должна остаться читаемой.
  Exercise _exerciseFromLog(String id, String name) {
    final found = exerciseById(id);
    if (found.id.isNotEmpty) return found;
    return Exercise(id: id, name: name, primaryMuscle: MuscleGroup.cardio, equipment: '—', difficulty: ExerciseDifficulty.beginner);
  }
}

ProgramGoal _goalFromJson(String value) => ProgramGoal.values.asNameMap()[value] ?? ProgramGoal.maintenance;
ProgramLevel _levelFromJson(String value) => ProgramLevel.values.asNameMap()[value] ?? ProgramLevel.beginner;
SessionStatus _statusFromJson(String value) => SessionStatus.values.asNameMap()[value] ?? SessionStatus.done;

final workoutApiServiceProvider = Provider<WorkoutApiService>((ref) => WorkoutApiService());
