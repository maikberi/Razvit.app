import 'nutrition.dart';

/// Одна запись о выпитой воде (см. backend water_entries) — позволяет
/// показать историю за день и редактировать/удалять конкретную запись,
/// а не только "последнюю добавленную".
class WaterEntry {
  const WaterEntry({required this.id, required this.amountMl, required this.loggedAt});

  final String id;
  final int amountMl;
  final DateTime loggedAt;

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
        id: json['id'] as String,
        amountMl: (json['amountMl'] as num).round(),
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );
}

/// Ответ backend на любую мутацию воды (POST/PUT/DELETE) и на GET —
/// всегда и итог за день, и сами записи, так что после любого действия
/// экран может сразу перерисовать и то, и другое без лишнего запроса.
class WaterDay {
  const WaterDay({required this.consumedMl, required this.entries});

  final int consumedMl;
  final List<WaterEntry> entries;

  factory WaterDay.fromJson(Map<String, dynamic> json) => WaterDay(
        consumedMl: (json['consumedMl'] as num).round(),
        entries: (json['entries'] as List<dynamic>? ?? const []).map((e) => WaterEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Продукт внутри приёма пищи — уже посчитанные backend'ом (Nutrition
/// Engine) значения на фактический вес порции, а не на 100 г. Flutter
/// здесь ничего не умножает и не делит, только показывает.
class MealEntryData {
  const MealEntryData({
    required this.id,
    required this.foodId,
    required this.name,
    required this.imageUrl,
    required this.emoji,
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
  final String? imageUrl;
  final String? emoji;
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
        imageUrl: json['imageUrl'] as String?,
        emoji: json['emoji'] as String?,
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

  /// Точечное обновление одного поля (сейчас — только вода) без полного
  /// перезапроса дня: используется, когда backend уже вернул готовое новое
  /// значение в ответе мутации (см. NutritionApiService.addWater).
  DailyNutritionSummary copyWith({int? waterConsumedMl}) => DailyNutritionSummary(
        date: date,
        meals: meals,
        consumedCalories: consumedCalories,
        consumedProtein: consumedProtein,
        consumedFat: consumedFat,
        consumedCarbs: consumedCarbs,
        targets: targets,
        remainingCalories: remainingCalories,
        remainingProtein: remainingProtein,
        remainingFat: remainingFat,
        remainingCarbs: remainingCarbs,
        progressPercent: progressPercent,
        waterConsumedMl: waterConsumedMl ?? this.waterConsumedMl,
      );
}
