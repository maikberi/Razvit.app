import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/nutrition.dart';
import '../models/nutrition_day.dart';

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

/// Всё, что нужно Nutrition Home Screen: дневная сводка (приёмы пищи +
/// цели + вода, посчитанные backend'ом), изменение приёмов пищи, воды
/// и целей. Никакой математики здесь нет — только вызовы API.
class NutritionApiService {
  NutritionApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

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

  Future<int> addWater(int amountMl, DateTime date) async {
    final json = await _client.postJson('/api/v1/nutrition/water', {'amountMl': amountMl, 'date': _formatDate(date)});
    return ((json['data'] as Map<String, dynamic>)['consumedMl'] as num).round();
  }

  Future<int> removeLastWater(DateTime date) async {
    final json = await _client.delete('/api/v1/nutrition/water/last', query: {'date': _formatDate(date)});
    return ((json['data'] as Map<String, dynamic>)['consumedMl'] as num).round();
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
}

final nutritionApiServiceProvider = Provider<NutritionApiService>((ref) => NutritionApiService());
