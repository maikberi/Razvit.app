import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/nutrition_day.dart';
import '../models/trainer_relation.dart';

/// Всё общение с реальным backend'ом ЭТАП 17 (trainer_clients + то, что
/// тренер назначает клиенту). Не путать с lib/data/repositories/
/// trainer_repository.dart — тот работает с мок-каталогом тренеров
/// (карточки/рейтинги/чат), это два независимых раздела приложения.
class TrainerApiService {
  TrainerApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> becomeTrainer() => _client.postJson('/api/v1/trainer/become', const {});

  Future<TrainerRelation> inviteClient(String email) async {
    final json = await _client.postJson('/api/v1/trainer/clients/invite', {'email': email});
    return TrainerRelation.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<TrainerRelation>> getMyClients() async {
    final json = await _client.getJson('/api/v1/trainer/clients');
    return (json['data'] as List<dynamic>).map((e) => TrainerRelation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TrainerRelation>> getMyInvites() async {
    final json = await _client.getJson('/api/v1/trainer/invites');
    return (json['data'] as List<dynamic>).map((e) => TrainerRelation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TrainerRelation>> getMyTrainers() async {
    final json = await _client.getJson('/api/v1/trainer/my-trainers');
    return (json['data'] as List<dynamic>).map((e) => TrainerRelation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> respondToInvite(String relationId, bool approve) =>
      _client.postJson('/api/v1/trainer/invites/$relationId/respond', {'approve': approve});

  Future<void> revokeRelation(String relationId) => _client.delete('/api/v1/trainer/relations/$relationId');

  // ---- Тренер смотрит данные клиента (backend сам проверяет approved-связь) ----

  Future<DailyNutritionSummary> getClientDaily(String clientId, DateTime date) async {
    final json = await _client.getJson('/api/v1/trainer/clients/$clientId/daily', query: {'date': _formatDate(date)});
    return DailyNutritionSummary.fromJson(json['data'] as Map<String, dynamic>);
  }

  // ---- Тренер назначает клиенту ----

  Future<CoachPlan> setClientPlan(
    String clientId, {
    String? title,
    int? calorieTarget,
    int? proteinTarget,
    String? notes,
  }) async {
    final json = await _client.putJson('/api/v1/trainer/clients/$clientId/plan', {
      if (title != null) 'title': title,
      if (calorieTarget != null) 'calorieTarget': calorieTarget,
      if (proteinTarget != null) 'proteinTarget': proteinTarget,
      if (notes != null) 'notes': notes,
    });
    return CoachPlan.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<CoachMealAssignment> assignMeal(
    String clientId, {
    String? recipeId,
    required String title,
    String? notes,
    String? mealType,
  }) async {
    final json = await _client.postJson('/api/v1/trainer/clients/$clientId/meal-assignments', {
      if (recipeId != null) 'recipeId': recipeId,
      'title': title,
      if (notes != null) 'notes': notes,
      if (mealType != null) 'mealType': mealType,
    });
    return CoachMealAssignment.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> removeAssignment(String assignmentId) => _client.delete('/api/v1/trainer/meal-assignments/$assignmentId');

  Future<CoachComment> addComment(String clientId, String message) async {
    final json = await _client.postJson('/api/v1/trainer/clients/$clientId/comments', {'message': message});
    return CoachComment.fromJson(json['data'] as Map<String, dynamic>);
  }

  // ---- Клиент читает своё (назначенное любым из его тренеров) ----

  Future<CoachPlan?> getMyCoachPlan() async {
    final json = await _client.getJson('/api/v1/trainer/coach-plan');
    final data = json['data'];
    return data == null ? null : CoachPlan.fromJson(data as Map<String, dynamic>);
  }

  Future<List<CoachMealAssignment>> getMyAssignments() async {
    final json = await _client.getJson('/api/v1/trainer/meal-assignments');
    return (json['data'] as List<dynamic>).map((e) => CoachMealAssignment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CoachComment>> getMyComments() async {
    final json = await _client.getJson('/api/v1/trainer/coach-comments');
    return (json['data'] as List<dynamic>).map((e) => CoachComment.fromJson(e as Map<String, dynamic>)).toList();
  }
}

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

final trainerApiServiceProvider = Provider<TrainerApiService>((ref) => TrainerApiService());

final myClientsProvider = FutureProvider.autoDispose<List<TrainerRelation>>((ref) => ref.watch(trainerApiServiceProvider).getMyClients());
final myInvitesProvider = FutureProvider.autoDispose<List<TrainerRelation>>((ref) => ref.watch(trainerApiServiceProvider).getMyInvites());
final myTrainersProvider = FutureProvider.autoDispose<List<TrainerRelation>>((ref) => ref.watch(trainerApiServiceProvider).getMyTrainers());
final myCoachPlanProvider = FutureProvider.autoDispose<CoachPlan?>((ref) => ref.watch(trainerApiServiceProvider).getMyCoachPlan());
final myAssignmentsProvider = FutureProvider.autoDispose<List<CoachMealAssignment>>((ref) => ref.watch(trainerApiServiceProvider).getMyAssignments());
final myCommentsProvider = FutureProvider.autoDispose<List<CoachComment>>((ref) => ref.watch(trainerApiServiceProvider).getMyComments());
