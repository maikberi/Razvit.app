import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nutrition.dart';
import '../models/nutrition_day.dart';
import '../services/food_service.dart';
import '../services/nutrition_api_service.dart';

/// Состояние Nutrition Home Screen для конкретной (выбранной) даты —
/// реальные данные с backend (см. NutritionApiService), без единой
/// mock-заглушки. Любое изменение (добавить продукт, воду, поменять
/// граммовку) просто перезапрашивает день заново — так проще
/// гарантировать, что показанное всегда совпадает с тем, что реально
/// посчитал backend.
class NutritionDayNotifier extends StateNotifier<AsyncValue<DailyNutritionSummary>> {
  NutritionDayNotifier(this._api) : super(const AsyncValue.loading()) {
    _load();
  }

  final NutritionApiService _api;
  DateTime _selectedDate = DateTime.now();

  DateTime get selectedDate => _selectedDate;

  bool get isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _api.getDaily(_selectedDate));
  }

  Future<void> refresh() => _load();

  Future<void> changeDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    await _load();
  }

  Future<void> goToPreviousDay() => changeDate(_selectedDate.subtract(const Duration(days: 1)));

  Future<void> goToNextDay() => changeDate(_selectedDate.add(const Duration(days: 1)));

  Future<void> addFoodItem({
    required String mealId,
    String? foodId,
    String? name,
    ManualNutrients? nutrients,
    required double grams,
  }) async {
    await _api.addItem(mealId: mealId, foodId: foodId, name: name, nutrients: nutrients, grams: grams);
    await _load();
  }

  Future<void> updateItemGrams(String itemId, double grams) async {
    await _api.updateItemGrams(itemId, grams);
    await _load();
  }

  Future<void> deleteItem(String itemId) async {
    await _api.deleteItem(itemId);
    await _load();
  }

  Future<void> addWater(int amountMl) async {
    await _api.addWater(amountMl, _selectedDate);
    await _load();
  }

  Future<void> removeLastWater() async {
    await _api.removeLastWater(_selectedDate);
    await _load();
  }
}

final nutritionDayProvider = StateNotifierProvider<NutritionDayNotifier, AsyncValue<DailyNutritionSummary>>((ref) {
  return NutritionDayNotifier(ref.watch(nutritionApiServiceProvider));
});

/// Последние использованные продукты — для секции Recent Foods.
final recentFoodsProvider = FutureProvider.autoDispose<List<FoodItem>>((ref) {
  return ref.watch(foodServiceProvider).getRecent();
});
