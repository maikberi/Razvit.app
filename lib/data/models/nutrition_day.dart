import 'nutrition.dart';

/// Продукт внутри приёма пищи — уже посчитанные backend'ом (Nutrition
/// Engine) значения на фактический вес порции, а не на 100 г. Flutter
/// здесь ничего не умножает и не делит, только показывает.
class MealEntryData {
  const MealEntryData({
    required this.id,
    required this.foodId,
    required this.name,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.fiber,
    required this.sugar,
    required this.sodium,
  });

  final String id;
  final String? foodId;
  final String name;
  final double grams;
  final int calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final double fiber;
  final double? sugar;
  final double? sodium;

  factory MealEntryData.fromJson(Map<String, dynamic> json) => MealEntryData(
        id: json['id'] as String,
        foodId: json['foodId'] as String?,
        name: json['name'] as String,
        grams: (json['grams'] as num).toDouble(),
        calories: (json['calories'] as num).round(),
        protein: (json['protein'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        carbohydrates: (json['carbohydrates'] as num).toDouble(),
        fiber: (json['fiber'] as num).toDouble(),
        sugar: (json['sugar'] as num?)?.toDouble(),
        sodium: (json['sodium'] as num?)?.toDouble(),
      );
}

/// Один приём пищи с посчитанными итогами (тоже с backend, не суммируется
/// на клиенте из отдельных продуктов).
class MealData {
  const MealData({
    required this.id,
    required this.type,
    required this.time,
    required this.items,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
  });

  final String id;
  final MealType type;
  final String? time;
  final List<MealEntryData> items;
  final int calories;
  final double protein;
  final double fat;
  final double carbohydrates;

  factory MealData.fromJson(Map<String, dynamic> json) => MealData(
        id: json['id'] as String,
        type: MealType.values.byName(json['type'] as String),
        time: json['time'] as String?,
        items: (json['items'] as List<dynamic>).map((e) => MealEntryData.fromJson(e as Map<String, dynamic>)).toList(),
        calories: (json['calories'] as num).round(),
        protein: (json['protein'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        carbohydrates: (json['carbohydrates'] as num).toDouble(),
      );
}

/// Всё, что нужно Nutrition Home Screen на одну дату — единый ответ
/// backend'а (GET /nutrition/daily): приёмы пищи, съедено/цель/осталось
/// по калориям и БЖУ, прогресс, вода. Ничего из этого Flutter не считает
/// сам — только показывает готовые числа.
class DailyNutritionSummary {
  const DailyNutritionSummary({
    required this.date,
    required this.meals,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedFat,
    required this.consumedCarbs,
    required this.targets,
    required this.remainingCalories,
    required this.remainingProtein,
    required this.remainingFat,
    required this.remainingCarbs,
    required this.progressPercent,
    required this.waterConsumedMl,
  });

  final DateTime date;
  final List<MealData> meals;
  final int consumedCalories;
  final double consumedProtein;
  final double consumedFat;
  final double consumedCarbs;
  final NutritionPlan targets;
  final int remainingCalories;
  final double remainingProtein;
  final double remainingFat;
  final double remainingCarbs;
  final int progressPercent;
  final int waterConsumedMl;

  factory DailyNutritionSummary.fromJson(Map<String, dynamic> json) {
    final consumed = json['consumed'] as Map<String, dynamic>;
    final targetsJson = json['targets'] as Map<String, dynamic>;
    final remaining = json['remaining'] as Map<String, dynamic>;
    final water = json['water'] as Map<String, dynamic>;
    final progressPercent = (json['progressPercent'] as num).round();

    return DailyNutritionSummary(
      date: DateTime.parse(json['date'] as String),
      meals: (json['meals'] as List<dynamic>).map((m) => MealData.fromJson(m as Map<String, dynamic>)).toList(),
      consumedCalories: (consumed['calories'] as num).round(),
      consumedProtein: (consumed['protein'] as num).toDouble(),
      consumedFat: (consumed['fat'] as num).toDouble(),
      consumedCarbs: (consumed['carbohydrates'] as num).toDouble(),
      targets: NutritionPlan.fromTargetsJson(targetsJson, progressPercent: progressPercent),
      remainingCalories: (remaining['calories'] as num).round(),
      remainingProtein: (remaining['protein'] as num).toDouble(),
      remainingFat: (remaining['fat'] as num).toDouble(),
      remainingCarbs: (remaining['carbohydrates'] as num).toDouble(),
      progressPercent: progressPercent,
      waterConsumedMl: (water['consumedMl'] as num).round(),
    );
  }

  MealData mealOf(MealType type) => meals.firstWhere((m) => m.type == type);
}
