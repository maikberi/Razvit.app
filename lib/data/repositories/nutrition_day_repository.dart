import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nutrition.dart';
import '../models/nutrition_day.dart';
import '../services/food_service.dart';
import '../services/nutrition_api_service.dart';

String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Состояние Nutrition Home Screen для конкретной (выбранной) даты —
/// реальные данные с backend (см. NutritionApiService).
///
/// Важно: `state` переходит в AsyncValue.loading() ТОЛЬКО при самом первом
/// открытии экрана. Дальше — при смене даты, добавлении/удалении еды,
/// изменении граммовки — старые данные остаются на экране, пока не придут
/// новые ("тихое" обновление). Это и есть исправление "полной перезагрузки"
/// экрана: она была не от медленного backend, а от того, что state каждый
/// раз сбрасывался в loading, из-за чего NutritionScreen.when(...) рисовал
/// LoadingView() поверх всего экрана.
///
/// Даты, которые пользователь уже открывал в этой сессии, кэшируются в
/// памяти (_cache) — повторное открытие той же даты происходит мгновенно,
/// без похода на backend.
class NutritionDayNotifier extends StateNotifier<AsyncValue<DailyNutritionSummary>> {
  NutritionDayNotifier(this._ref, this._api) : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  final Ref _ref;
  final NutritionApiService _api;
  final Map<String, DailyNutritionSummary> _cache = {};

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  bool get isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
  }

  Future<void> _loadInitial() async {
    final result = await AsyncValue.guard(() => _api.getDaily(_selectedDate));
    result.whenData((data) => _cache[_dateKey(_selectedDate)] = data);
    state = result;
  }

  /// Перезапрашивает текущий день в фоне, не трогая state до получения
  /// ответа — если запрос упадёт, на экране просто останется то, что было
  /// (см. class-level комментарий), а ошибка уйдёт вызывающему коду.
  Future<void> _silentReload() async {
    final data = await _api.getDaily(_selectedDate);
    _cache[_dateKey(_selectedDate)] = data;
    state = AsyncValue.data(data);
  }

  /// Пул-ту-рефреш (RefreshIndicator сам показывает свой индикатор,
  /// глобальный loading здесь не нужен).
  Future<void> refresh() => _silentReload();

  Future<void> changeDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized == _selectedDate) return;

    final previousDate = _selectedDate;
    _selectedDate = normalized;

    final cached = _cache[_dateKey(normalized)];
    if (cached != null) {
      state = AsyncValue.data(cached);
      return;
    }

    // Нет в кэше — грузим в фоне; предыдущие данные остаются на экране
    // (см. class-level комментарий), только маленький индикатор в шапке
    // (isDateTransitioningProvider) показывает, что идёт подгрузка.
    _ref.read(isDateTransitioningProvider.notifier).state = true;
    try {
      final data = await _api.getDaily(normalized);
      _cache[_dateKey(normalized)] = data;
      if (_selectedDate == normalized) state = AsyncValue.data(data);
    } catch (_) {
      _selectedDate = previousDate; // откатываем, чтобы шапка не разъезжалась с показанными данными
      rethrow;
    } finally {
      _ref.read(isDateTransitioningProvider.notifier).state = false;
    }
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
    await _silentReload();
    _ref.invalidate(recentFoodsProvider); // только что добавленный продукт мог стать "недавним"
  }

  Future<void> updateItemGrams(String itemId, double grams) async {
    await _api.updateItemGrams(itemId, grams);
    await _silentReload();
  }

  Future<void> deleteItem(String itemId) async {
    await _api.deleteItem(itemId);
    await _silentReload();
  }

  /// Точечное обновление: backend уже возвращает готовое consumedMl в
  /// ответе на добавление/удаление воды — полный перезапрос дня не нужен.
  Future<void> addWater(int amountMl) async {
    final consumedMl = await _api.addWater(amountMl, _selectedDate);
    _patchWater(consumedMl);
  }

  Future<void> removeLastWater() async {
    final consumedMl = await _api.removeLastWater(_selectedDate);
    _patchWater(consumedMl);
  }

  void _patchWater(int consumedMl) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.copyWith(waterConsumedMl: consumedMl);
    _cache[_dateKey(_selectedDate)] = updated;
    state = AsyncValue.data(updated);
  }
}

final nutritionDayProvider = StateNotifierProvider<NutritionDayNotifier, AsyncValue<DailyNutritionSummary>>((ref) {
  return NutritionDayNotifier(ref, ref.watch(nutritionApiServiceProvider));
});

/// Идёт ли сейчас фоновая подгрузка ещё не закэшированной даты — маленький
/// индикатор в шапке, а не полноэкранный loader (см. changeDate выше).
final isDateTransitioningProvider = StateProvider<bool>((ref) => false);

/// Последние использованные продукты — для секции Recent Foods.
final recentFoodsProvider = FutureProvider.autoDispose<List<FoodItem>>((ref) {
  return ref.watch(foodServiceProvider).getRecent();
});
