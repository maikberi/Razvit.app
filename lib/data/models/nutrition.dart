enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Завтрак',
        MealType.lunch => 'Обед',
        MealType.dinner => 'Ужин',
        MealType.snack => 'Перекус',
      };
}

/// Продукт из базы (на 100 г, если не указано иное).
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.carbsPer100g,
    this.defaultGrams = 100,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final int caloriesPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double carbsPer100g;
  final int defaultGrams;
  final bool isFavorite;
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
}
