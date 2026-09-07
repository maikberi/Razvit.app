import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_nutrition.dart';
import '../mock/mock_nutrition_history.dart';
import '../models/nutrition.dart';

final foodCatalogProvider = Provider<List<FoodItem>>((ref) => mockFoods);
final recipesProvider = Provider<List<Recipe>>((ref) => mockRecipes);

class NutritionPlanNotifier extends StateNotifier<NutritionPlan> {
  NutritionPlanNotifier() : super(mockNutritionPlan);

  void update({int? calorieGoal, int? proteinGoal, int? fatGoal, int? carbsGoal, int? waterGoalMl}) {
    state = state.copyWith(
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      fatGoal: fatGoal,
      carbsGoal: carbsGoal,
      waterGoalMl: waterGoalMl,
    );
  }
}

final nutritionPlanProvider = StateNotifierProvider<NutritionPlanNotifier, NutritionPlan>((ref) => NutritionPlanNotifier());

/// История питания за последние ~90 дней (без сегодняшнего — он берётся
/// из реального состояния приёмов пищи и воды).
final nutritionHistoryProvider = Provider<List<NutritionDayLog>>((ref) {
  final plan = ref.watch(nutritionPlanProvider);
  return generateMockNutritionHistory(
    calorieGoal: plan.calorieGoal,
    proteinGoal: plan.proteinGoal,
    fatGoal: plan.fatGoal,
    carbsGoal: plan.carbsGoal,
    waterGoalMl: plan.waterGoalMl,
  );
});

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

  void updateGrams(MealType type, int entryIndex, int grams) {
    state = [
      for (final meal in state)
        if (meal.type == type)
          Meal(
            type: meal.type,
            time: meal.time,
            entries: [
              for (var i = 0; i < meal.entries.length; i++)
                if (i == entryIndex) FoodEntry(food: meal.entries[i].food, grams: grams) else meal.entries[i],
            ],
          )
        else
          meal,
    ];
  }

  void removeFood(MealType type, int entryIndex) {
    state = [
      for (final meal in state)
        if (meal.type == type)
          Meal(type: meal.type, time: meal.time, entries: [for (var i = 0; i < meal.entries.length; i++) if (i != entryIndex) meal.entries[i]])
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
  void set(int ml) => state = ml.clamp(0, 1 << 30);
  void reset() => state = 0;
}

final waterIntakeProvider = StateNotifierProvider<WaterNotifier, int>((ref) => WaterNotifier());
