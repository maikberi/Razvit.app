enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Завтрак',
        MealType.lunch => 'Обед',
        MealType.dinner => 'Ужин',
        MealType.snack => 'Перекус',
      };
}

/// Продукт из базы (на 100 г, если не указано иное — см. [basisUnit]).
///
/// Поля brand/barcode/category/source/sugarPer100g/sodiumPer100g/
/// servingUnit/micronutrients — расширение под Food Database backend
/// (см. backend/src/modules/food). Все опциональны, так что существующие
/// mock-продукты (mock_nutrition.dart) не меняются.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbsPer100g,
    this.fiberPer100g = 0,
    this.defaultGrams = 100,
    this.isFavorite = false,
    this.brand,
    this.barcode,
    this.category,
    this.source = FoodSource.razvit,
    this.basisUnit = FoodBasisUnit.grams,
    this.sugarPer100g,
    this.sodiumPer100g,
    this.servingUnit,
    this.micronutrients = const {},
  });

  final String id;
  final String name;
  final int caloriesPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbsPer100g;
  final double fiberPer100g;
  final int defaultGrams;
  final bool isFavorite;
  final String? brand;
  final String? barcode;
  final String? category;
  final FoodSource source;
  final FoodBasisUnit basisUnit;
  final double? sugarPer100g;
  final double? sodiumPer100g;
  final String? servingUnit;
  final Map<String, FoodMicronutrient> micronutrients;

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        name: json['name'] as String,
        caloriesPer100g: (json['caloriesPer100g'] as num).round(),
        proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
        fatPer100g: (json['fatPer100g'] as num).toDouble(),
        carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
        fiberPer100g: (json['fiberPer100g'] as num?)?.toDouble() ?? 0,
        defaultGrams: (json['defaultGrams'] as num?)?.round() ?? 100,
        brand: json['brand'] as String?,
        barcode: json['barcode'] as String?,
        category: json['category'] as String?,
        source: FoodSourceX.fromJson(json['source'] as String?),
        basisUnit: (json['basisUnit'] as String?) == 'ml' ? FoodBasisUnit.milliliters : FoodBasisUnit.grams,
        sugarPer100g: (json['sugarPer100g'] as num?)?.toDouble(),
        sodiumPer100g: (json['sodiumPer100g'] as num?)?.toDouble(),
        servingUnit: json['servingUnit'] as String?,
        micronutrients: (json['micronutrients'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, FoodMicronutrient.fromJson(value as Map<String, dynamic>)),
            ) ??
            const {},
      );
}

enum FoodSource { razvit, usda, off }

extension FoodSourceX on FoodSource {
  static FoodSource fromJson(String? raw) => switch (raw) {
        'USDA' => FoodSource.usda,
        'OFF' => FoodSource.off,
        _ => FoodSource.razvit,
      };

  /// Короткая подпись источника для UI (например, в детальной карточке продукта).
  String get label => switch (this) {
        FoodSource.razvit => 'RAZVIT',
        FoodSource.usda => 'USDA',
        FoodSource.off => 'Open Food Facts',
      };
}

enum FoodBasisUnit { grams, milliliters }

extension FoodBasisUnitX on FoodBasisUnit {
  String get label => this == FoodBasisUnit.milliliters ? 'мл' : 'г';
}

class FoodMicronutrient {
  const FoodMicronutrient({required this.amount, required this.unit});

  final double amount;
  final String unit;

  factory FoodMicronutrient.fromJson(Map<String, dynamic> json) => FoodMicronutrient(
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String,
      );
}

/// Запись о приёме конкретного продукта в рамках приёма пищи.
class FoodEntry {
  const FoodEntry({required this.food, required this.grams});

  final FoodItem food;
  final int grams;

  double get _ratio => grams / 100.0;
  int get calories => (food.caloriesPer100g * _ratio).round();
  double get protein => food.proteinPer100g * _ratio;
  double get fat => food.fatPer100g * _ratio;
  double get carbs => food.carbsPer100g * _ratio;
}

class Meal {
  const Meal({required this.type, required this.time, this.entries = const []});

  final MealType type;
  final String time;
  final List<FoodEntry> entries;

  int get calories => entries.fold(0, (sum, e) => sum + e.calories);
  double get protein => entries.fold(0, (sum, e) => sum + e.protein);
  double get fat => entries.fold(0, (sum, e) => sum + e.fat);
  double get carbs => entries.fold(0, (sum, e) => sum + e.carbs);
}

enum RecipeTag { breakfast, lunch, dinner, snack, highProtein, lowCalorie }

extension RecipeTagX on RecipeTag {
  String get label => switch (this) {
        RecipeTag.breakfast => 'Завтрак',
        RecipeTag.lunch => 'Обед',
        RecipeTag.dinner => 'Ужин',
        RecipeTag.snack => 'Перекус',
        RecipeTag.highProtein => 'Высокобелковые',
        RecipeTag.lowCalorie => 'Низкокалорийные',
      };
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.minutes,
    required this.difficulty,
    required this.tags,
    this.isNew = false,
    this.isPopular = false,
    this.isFavorite = false,
    this.colorSeed = 0,
  });

  final String id;
  final String title;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final int minutes;
  final String difficulty;
  final List<RecipeTag> tags;
  final bool isNew;
  final bool isPopular;
  final bool isFavorite;
  final int colorSeed;
}

class NutritionPlan {
  const NutritionPlan({
    required this.title,
    required this.calorieGoal,
    required this.proteinGoal,
    required this.fatGoal,
    required this.carbsGoal,
    required this.waterGoalMl,
    required this.validUntil,
    required this.progressPercent,
  });

  final String title;
  final int calorieGoal;
  final int proteinGoal;
  final int fatGoal;
  final int carbsGoal;
  final int waterGoalMl;
  final DateTime validUntil;
  final int progressPercent;

  /// Из ответа backend (GET/PUT /nutrition/targets) — там нет validUntil
  /// (это не длительность плана, а просто цели) и progressPercent
  /// (он есть только в контексте конкретного дня, см. DailyNutritionSummary),
  /// поэтому progressPercent передаётся отдельно вызывающей стороной.
  factory NutritionPlan.fromTargetsJson(Map<String, dynamic> json, {int progressPercent = 0}) => NutritionPlan(
        title: json['title'] as String,
        calorieGoal: (json['calorieGoal'] as num).round(),
        proteinGoal: (json['proteinGoal'] as num).round(),
        fatGoal: (json['fatGoal'] as num).round(),
        carbsGoal: (json['carbsGoal'] as num).round(),
        waterGoalMl: (json['waterGoalMl'] as num).round(),
        validUntil: DateTime.now(),
        progressPercent: progressPercent,
      );

  NutritionPlan copyWith({
    int? calorieGoal,
    int? proteinGoal,
    int? fatGoal,
    int? carbsGoal,
    int? waterGoalMl,
  }) {
    return NutritionPlan(
      title: title,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      validUntil: validUntil,
      progressPercent: progressPercent,
    );
  }
}
