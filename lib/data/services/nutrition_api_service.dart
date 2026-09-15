import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/nutrition.dart';
import '../models/nutrition_day.dart';
import '../models/nutrition_profile.dart';

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Нутриенты для ручного ввода продукта, которого нет в базе (на 100 г).
class ManualNutrients {
  const ManualNutrients({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    this.fiber = 0,
    this.sugar,
    this.sodium,
  });

  final double calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final double fiber;
  final double? sugar;
  final double? sodium;

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbohydrates': carbohydrates,
        'fiber': fiber,
        if (sugar != null) 'sugar': sugar,
        if (sodium != null) 'sodium': sodium,
      };
}

/// Превью КБЖУ для выбранного количества — результат чистого расчётного
/// эндпоинта (без сохранения), см. calculateFood ниже.
class NutrientPreview {
  const NutrientPreview({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
  });

  final int calories;
  final double protein;
  final double fat;
  final double carbohydrates;

  factory NutrientPreview.fromJson(Map<String, dynamic> json) => NutrientPreview(
        calories: (json['calories'] as num).round(),
        protein: (json['protein'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        carbohydrates: (json['carbohydrates'] as num).toDouble(),
      );
}

/// Всё, что нужно Nutrition Home Screen: дневная сводка (приёмы пищи +
/// цели + вода, посчитанные backend'ом), изменение приёмов пищи, воды
/// и целей. Никакой математики здесь нет — только вызовы API.
class NutritionApiService {
  NutritionApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Чистый расчёт (ничего не сохраняет) — используется для live-превью
  /// КБЖУ при выборе количества, чтобы не дублировать формулу Nutrition
  /// Engine во Flutter (см. backend nutrition.controller.calculateFood).
  Future<NutrientPreview> calculateFood({required String foodId, required double grams}) async {
    final json = await _client.postJson('/api/v1/nutrition/calculate/food', {'foodId': foodId, 'grams': grams});
    return NutrientPreview.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<DailyNutritionSummary> getDaily(DateTime date) async {
    final json = await _client.getJson('/api/v1/nutrition/daily', query: {'date': _formatDate(date)});
    return DailyNutritionSummary.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> addItem({
    required String mealId,
    String? foodId,
    String? name,
    ManualNutrients? nutrients,
    required double grams,
  }) async {
    await _client.postJson('/api/v1/meals/$mealId/items', {
      if (foodId != null) 'foodId': foodId,
      if (name != null) 'name': name,
      if (nutrients != null) 'nutrients': nutrients.toJson(),
      'grams': grams,
    });
  }

  Future<void> updateItemGrams(String itemId, double grams) async {
    await _client.patchJson('/api/v1/meal-items/$itemId', {'grams': grams});
  }

  Future<void> deleteItem(String itemId) async {
    await _client.delete('/api/v1/meal-items/$itemId');
  }

  Future<WaterDay> getWaterDay(DateTime date) async {
    final json = await _client.getJson('/api/v1/nutrition/water', query: {'date': _formatDate(date)});
    return WaterDay.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<WaterDay> addWater(int amountMl, DateTime date) async {
    final json = await _client.postJson('/api/v1/nutrition/water', {'amountMl': amountMl, 'date': _formatDate(date)});
    return WaterDay.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<WaterDay> removeLastWater(DateTime date) async {
    final json = await _client.delete('/api/v1/nutrition/water/last', query: {'date': _formatDate(date)});
    return WaterDay.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<WaterDay> updateWaterEntry(String id, int amountMl) async {
    final json = await _client.putJson('/api/v1/nutrition/water/${Uri.encodeComponent(id)}', {'amountMl': amountMl});
    return WaterDay.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<WaterDay> deleteWaterEntry(String id) async {
    final json = await _client.delete('/api/v1/nutrition/water/${Uri.encodeComponent(id)}');
    return WaterDay.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<NutritionPlan> getTargets() async {
    final json = await _client.getJson('/api/v1/nutrition/targets');
    return NutritionPlan.fromTargetsJson(json['data'] as Map<String, dynamic>);
  }

  Future<NutritionPlan> updateTargets({
    required String title,
    required int calorieGoal,
    required int proteinGoal,
    required int fatGoal,
    required int carbsGoal,
    required int waterGoalMl,
  }) async {
    final json = await _client.putJson('/api/v1/nutrition/targets', {
      'title': title,
      'calorieGoal': calorieGoal,
      'proteinGoal': proteinGoal,
      'fatGoal': fatGoal,
      'carbsGoal': carbsGoal,
      'waterGoalMl': waterGoalMl,
    });
    return NutritionPlan.fromTargetsJson(json['data'] as Map<String, dynamic>);
  }

  Future<NutritionProfile> getProfile() async {
    final json = await _client.getJson('/api/v1/nutrition/profile');
    return NutritionProfile.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<NutritionProfile> updateProfile({
    NutritionSex? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    NutritionGoal? goal,
  }) async {
    final json = await _client.putJson('/api/v1/nutrition/profile', {
      if (sex != null) 'sex': sex.apiValue,
      if (age != null) 'age': age,
      if (heightCm != null) 'heightCm': heightCm,
      if (weightKg != null) 'weightKg': weightKg,
      if (activityLevel != null) 'activityLevel': activityLevel.apiValue,
      if (goal != null) 'goal': goal.apiValue,
    });
    return NutritionProfile.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Nutrition Target Service на backend: BMR/TDEE -> Goal adjustment ->
  /// Calories -> Macros из текущего профиля — и сразу сохраняет результат
  /// как новые цели (их по-прежнему можно поправить вручную через updateTargets).
  Future<NutritionPlan> generateTargets() async {
    final json = await _client.postJson('/api/v1/nutrition/targets/generate', const {});
    return NutritionPlan.fromTargetsJson(json['data'] as Map<String, dynamic>);
  }
}

final nutritionApiServiceProvider = Provider<NutritionApiService>((ref) => NutritionApiService());
