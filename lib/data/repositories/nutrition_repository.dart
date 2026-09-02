import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_nutrition.dart';
import '../models/nutrition.dart';

final foodCatalogProvider = Provider<List<FoodItem>>((ref) => mockFoods);
final recipesProvider = Provider<List<Recipe>>((ref) => mockRecipes);
final nutritionPlanProvider = Provider<NutritionPlan>((ref) => mockNutritionPlan);

class MealsNotifier extends StateNotifier<List<Meal>> {
  MealsNotifier() : super(buildTodayMeals());

  void addFood(MealType type, FoodItem food, int grams) {
    state = [
      for (final meal in state)
        if (meal.type == type)
          Meal(type: meal.type, time: meal.time, entries: [...meal.entries, FoodEntry(food: food, grams: grams)])
        else
          meal,
    ];
  }

  int get totalCalories => state.fold(0, (sum, m) => sum + m.calories);
  double get totalProtein => state.fold(0, (sum, m) => sum + m.protein);
  double get totalFat => state.fold(0, (sum, m) => sum + m.fat);
  double get totalCarbs => state.fold(0, (sum, m) => sum + m.carbs);
}

final mealsProvider = StateNotifierProvider<MealsNotifier, List<Meal>>((ref) => MealsNotifier());

class WaterNotifier extends StateNotifier<int> {
  WaterNotifier() : super(1600); // мл

  void add(int ml) => state += ml;
  void reset() => state = 0;
}

final waterIntakeProvider = StateNotifierProvider<WaterNotifier, int>((ref) => WaterNotifier());
