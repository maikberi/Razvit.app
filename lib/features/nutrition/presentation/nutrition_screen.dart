import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/models/nutrition_day.dart';
import '../../../data/repositories/nutrition_day_repository.dart';
import '../../../data/services/nutrition_api_service.dart';
import 'add_food_method_sheet.dart';
import 'food_ui.dart';

(IconData, Color, Color) _mealStyle(MealType t) => switch (t) {
      MealType.breakfast => (Icons.free_breakfast_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF4DF)),
      MealType.lunch => (Icons.lunch_dining_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      MealType.dinner => (Icons.dinner_dining_rounded, const Color(0xFF8B5CF6), const Color(0xFFF2ECFE)),
      MealType.snack => (Icons.cookie_rounded, AppColors.green600, AppColors.green50),
    };

/// К какому приёму пищи по умолчанию относить "быстрое добавление" —
/// чтобы пользователю не нужно было отдельно выбирать приём пищи
/// (шаг убран, минимизируем количество действий).
MealType _currentMealTypeByTime([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 11) return MealType.breakfast;
  if (hour < 16) return MealType.lunch;
  if (hour < 21) return MealType.dinner;
  return MealType.snack;
}

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  final Set<MealType> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final dayState = ref.watch(nutritionDayProvider);
    final notifier = ref.read(nutritionDayProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Питание'),
        actions: [
          IconButton(onPressed: () => context.push('/notifications'), icon: const Icon(Icons.notifications_none_rounded)),
        ],
      ),
      body: SafeArea(
        child: dayState.when(
          loading: () => const LoadingView(),
          error: (err, st) => ErrorView(
            message: err is ApiException ? err.message : 'Не удалось загрузить данные питания',
            onRetry: notifier.refresh,
          ),
          data: (summary) => _NutritionContent(
            summary: summary,
            expanded: _expanded,
            onToggleMeal: (type) => setState(() {
              if (!_expanded.add(type)) _expanded.remove(type);
            }),
          ),
        ),
      ),
    );
  }
}

class _NutritionContent extends ConsumerWidget {
  const _NutritionContent({required this.summary, required this.expanded, required this.onToggleMeal});

  final DailyNutritionSummary summary;
  final Set<MealType> expanded;
  final ValueChanged<MealType> onToggleMeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(nutritionDayProvider.notifier);
    final recentFoodsAsync = ref.watch(recentFoodsProvider);
    final isTransitioning = ref.watch(isDateTransitioningProvider);
    final currentMealType = _currentMealTypeByTime();
    final currentMeal = summary.mealOf(currentMealType);

    Future<void> handleDateChange(Future<void> Function() change) async {
      try {
        await change();
      } on ApiException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
      }
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
        children: [
          _DateHeader(
            date: summary.date,
            isToday: notifier.isToday,
            isLoading: isTransitioning,
            onPrev: () => handleDateChange(notifier.goToPreviousDay),
            onNext: notifier.isToday ? null : () => handleDateChange(notifier.goToNextDay),
            onPickDate: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: summary.date,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (picked != null) await handleDateChange(() => notifier.changeDate(picked));
            },
            onOpenStats: () => context.push('/nutrition-stats'),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Данные дня плавно приглушаются на время фоновой подгрузки ещё не
          // закэшированной даты — сами числа при этом не исчезают и не
          // прыгают, только чуть теряют контраст (см. isDateTransitioningProvider).
          AnimatedOpacity(
            opacity: isTransitioning ? 0.5 : 1,
            duration: const Duration(milliseconds: 150),
            child: _CalorieCard(summary: summary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Быстрое добавление', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _QuickAddRow(mealId: currentMeal.id, mealType: currentMealType),
          const SizedBox(height: AppSpacing.lg),
          _WaterCard(consumedMl: summary.waterConsumedMl, goalMl: summary.targets.waterGoalMl),
          const SizedBox(height: AppSpacing.lg),
          recentFoodsAsync.when(
            data: (foods) => foods.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _RecentFoodsSection(foods: foods, mealId: currentMeal.id),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Text('Приёмы пищи', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          AnimatedOpacity(
            opacity: isTransitioning ? 0.5 : 1,
            duration: const Duration(milliseconds: 150),
            child: Column(
              children: [
                for (final meal in summary.meals) ...[
                  _MealSection(meal: meal, expanded: expanded.contains(meal.type), onToggle: () => onToggleMeal(meal.type)),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.isToday,
    required this.isLoading,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
    required this.onOpenStats,
  });

  final DateTime date;
  final bool isToday;
  final bool isLoading;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPickDate;
  final VoidCallback onOpenStats;

  @override
  Widget build(BuildContext context) {
    final label = isToday ? 'Сегодня' : DateFormat('d MMMM', 'ru').format(date);
    return Row(
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded), visualDensity: VisualDensity.compact),
        Expanded(
          child: GestureDetector(
            onTap: onPickDate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink400),
                        )
                      : const Icon(Icons.keyboard_arrow_down_rounded, key: ValueKey('arrow'), size: 18, color: AppColors.ink500),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          visualDensity: VisualDensity.compact,
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
          ),
          child: IconButton(
            onPressed: onOpenStats,
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

class _CalorieCard extends StatelessWidget {
  const _CalorieCard({required this.summary});
  final DailyNutritionSummary summary;

  @override
  Widget build(BuildContext context) {
    final remaining = summary.remainingCalories;
    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            progress: summary.targets.calorieGoal == 0 ? 0 : (summary.consumedCalories / summary.targets.calorieGoal).clamp(0, 1),
            size: 132,
            strokeWidth: 11,
            color: AppColors.green500,
            trackColor: AppColors.green100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${summary.consumedCalories}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('/ ${summary.targets.calorieGoal} ккал', style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
                const SizedBox(height: 8),
                const Text('Осталось', style: TextStyle(color: AppColors.ink500, fontSize: 11)),
                Text(
                  remaining >= 0 ? '$remaining ккал' : '${-remaining} ккал сверх',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _macroLine(context, 'Белки', summary.consumedProtein, summary.targets.proteinGoal, summary.remainingProtein),
                const SizedBox(height: 16),
                _macroLine(context, 'Жиры', summary.consumedFat, summary.targets.fatGoal, summary.remainingFat),
                const SizedBox(height: 16),
                _macroLine(context, 'Углеводы', summary.consumedCarbs, summary.targets.carbsGoal, summary.remainingCarbs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroLine(BuildContext context, String label, double consumed, int goal, double remaining) {
    final done = goal > 0 && consumed >= goal;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.green500, width: 1.5),
            color: done ? AppColors.green500 : Colors.transparent,
          ),
          child: Icon(Icons.check_rounded, size: 14, color: done ? Colors.white : AppColors.green500),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
              Text('${consumed.toStringAsFixed(0)} / $goal г', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(
                remaining >= 0 ? 'осталось ${remaining.toStringAsFixed(0)} г' : 'сверх на ${(-remaining).toStringAsFixed(0)} г',
                style: TextStyle(color: remaining >= 0 ? AppColors.ink400 : AppColors.error, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  const _QuickAddRow({required this.mealId, required this.mealType});
  final String mealId;
  final MealType mealType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _QuickAddButton(icon: Icons.camera_alt_rounded, label: 'Фото', onTap: () => openPhotoAi(context, mealId))),
        const SizedBox(width: 6),
        Expanded(
          child: _QuickAddButton(
            icon: Icons.search_rounded,
            label: 'Поиск',
            onTap: () => context.push('/add-food?mealId=$mealId&mealType=${mealType.name}'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: _QuickAddButton(icon: Icons.qr_code_scanner_rounded, label: 'Штрихкод', onTap: () => openBarcodeLookup(context, mealId))),
        const SizedBox(width: 6),
        Expanded(child: _QuickAddButton(icon: Icons.menu_book_outlined, label: 'Рецепт', onTap: () => context.push('/recipes'))),
        const SizedBox(width: 6),
        Expanded(child: _QuickAddButton(icon: Icons.edit_note_rounded, label: 'Вручную', onTap: () => openManualEntry(context, mealId))),
      ],
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.green600, size: 20),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Карточка воды сама управляет своим busy-состоянием — при нажатии
/// "+"/undo крутится только маленький спиннер на самой кнопке, весь
/// остальной экран (и даже остальная часть этой карточки) не перестраивается
/// в loading. Backend уже возвращает готовое consumedMl в ответе на
/// мутацию (см. NutritionDayNotifier._patchWater) — полного перезапроса
/// дня для воды не происходит вообще.
class _WaterCard extends ConsumerStatefulWidget {
  const _WaterCard({required this.consumedMl, required this.goalMl});
  final int consumedMl;
  final int goalMl;

  @override
  ConsumerState<_WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends ConsumerState<_WaterCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consumedMl = widget.consumedMl;
    final goalMl = widget.goalMl;
    final notifier = ref.read(nutritionDayProvider.notifier);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Вода', style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  Text('${(consumedMl / 1000).toStringAsFixed(1)} / ${(goalMl / 1000).toStringAsFixed(1)} л', style: Theme.of(context).textTheme.bodyMedium),
                  if (consumedMl > 0)
                    IconButton(
                      onPressed: _busy ? null : () => _run(notifier.removeLastWater),
                      icon: const Icon(Icons.undo_rounded, size: 18, color: AppColors.ink400),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < 8; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.water_drop_rounded, size: 22, color: (i + 1) * 250 <= consumedMl ? AppColors.water : AppColors.ink200),
                ),
              const Spacer(),
              GestureDetector(
                onTap: _busy ? null : () => _run(() => notifier.addWater(250)),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: AppColors.green500, shape: BoxShape.circle),
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(5),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentFoodsSection extends StatelessWidget {
  const _RecentFoodsSection({required this.foods, required this.mealId});
  final List<FoodItem> foods;
  final String mealId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Недавние продукты', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        // Фиксированная высота строки — карточки внутри одинаковой высоты
        // независимо от длины названия продукта (см. _RecentFoodChip).
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: foods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _RecentFoodChip(food: foods[i], mealId: mealId),
          ),
        ),
      ],
    );
  }
}

/// Карточка недавнего продукта: фиксированный размер, название — максимум
/// 2 строки с многоточием (никогда не ломает layout), кнопка "+" всегда в
/// одном и том же месте (низ-право). Тап по карточке или по "+" — одно и
/// то же действие: открыть компактный выбор количества (см. секцию 6
/// в постановке задачи), а не добавить продукт мгновенно и непонятно.
class _RecentFoodChip extends StatelessWidget {
  const _RecentFoodChip({required this.food, required this.mealId});
  final FoodItem food;
  final String mealId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: AppCard(
        padding: const EdgeInsets.all(10),
        onTap: () => _showFoodQuantitySheet(context, food: food, mealId: mealId),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FoodThumbnail(id: food.id, imageUrl: food.imageUrl, size: 30, iconSize: 15),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 22),
                  child: SizedBox(
                    height: 32,
                    child: Text(
                      food.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 22),
                  child: Text(
                    '${food.caloriesPer100g} ккал/100г',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink500),
                  ),
                ),
              ],
            ),
            const Positioned(right: 0, bottom: 0, child: _AddBadge()),
          ],
        ),
      ),
    );
  }
}

class _AddBadge extends StatelessWidget {
  const _AddBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(color: AppColors.green500, shape: BoxShape.circle),
      child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
    );
  }
}

void _showFoodQuantitySheet(BuildContext context, {required FoodItem food, required String mealId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _FoodQuantitySheet(food: food, mealId: mealId),
  );
}

/// Компактный выбор количества для быстрого добавления (из Recent Foods):
/// название, шаг по граммам, живой пересчёт КБЖУ через существующий чистый
/// расчётный эндпоинт backend (POST /nutrition/calculate/food — тот же
/// Nutrition Engine, никакой математики во Flutter), кнопка "Добавить" с
/// коротким подтверждением успеха вместо мгновенного молчаливого добавления.
class _FoodQuantitySheet extends ConsumerStatefulWidget {
  const _FoodQuantitySheet({required this.food, required this.mealId});
  final FoodItem food;
  final String mealId;

  @override
  ConsumerState<_FoodQuantitySheet> createState() => _FoodQuantitySheetState();
}

class _FoodQuantitySheetState extends ConsumerState<_FoodQuantitySheet> {
  late int _grams = widget.food.defaultGrams;
  Timer? _debounce;
  NutrientPreview? _preview;
  bool _adding = false;
  bool _added = false;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setGrams(int grams) {
    if (grams <= 0) return;
    setState(() {
      _grams = grams;
      _preview = null;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _recalculate);
  }

  Future<void> _recalculate() async {
    final requestedGrams = _grams;
    try {
      final preview = await ref.read(nutritionApiServiceProvider).calculateFood(foodId: widget.food.id, grams: requestedGrams.toDouble());
      if (!mounted || requestedGrams != _grams) return; // граммы уже сменились — этот ответ устарел
      setState(() => _preview = preview);
    } on ApiException {
      // Тихо: цифры превью просто не покажутся, но добавление всё равно
      // сработает — реальный расчёт при сохранении всегда делает backend.
    }
  }

  Future<void> _add() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = true);
    try {
      await container.read(nutritionDayProvider.notifier).addFoodItem(mealId: widget.mealId, foodId: widget.food.id, grams: _grams.toDouble());
      if (!mounted) return;
      setState(() {
        _adding = false;
        _added = true;
      });
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('${widget.food.name} добавлено')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _adding = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final unit = food.basisUnit.label;
    final preview = _preview;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FoodThumbnail(id: food.id, imageUrl: food.imageUrl, size: 52, iconSize: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: Theme.of(context).textTheme.headlineMedium),
                    if (food.brand != null && food.brand!.isNotEmpty)
                      Text(food.brand!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
                    Text('${food.caloriesPer100g} ккал / 100 $unit', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Количество', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: _grams > 10 ? () => _setGrams(_grams - 10) : null,
                icon: const Icon(Icons.remove_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
              ),
              SizedBox(width: 100, child: Text('$_grams $unit', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium)),
              IconButton.filled(
                onPressed: () => _setGrams(_grams + 10),
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: preview == null
                ? const Padding(
                    key: ValueKey('calculating'),
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : Column(
                    key: const ValueKey('preview'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Итого', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(child: _statColumn(context, 'Калории', '${preview.calories}')),
                          Expanded(child: _statColumn(context, 'Белки', '${preview.protein.toStringAsFixed(1)} г')),
                          Expanded(child: _statColumn(context, 'Жиры', '${preview.fat.toStringAsFixed(1)} г')),
                          Expanded(child: _statColumn(context, 'Углеводы', '${preview.carbohydrates.toStringAsFixed(1)} г')),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _adding || _added ? null : _add,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _added
                    ? const Row(
                        key: ValueKey('done'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.check_rounded), SizedBox(width: 8), Text('Добавлено')],
                      )
                    : _adding
                        ? const SizedBox(
                            key: ValueKey('busy'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Добавить', key: ValueKey('idle')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal, required this.expanded, required this.onToggle});
  final MealData meal;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final style = _mealStyle(meal.type);

    return AppCard(
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: style.$3, shape: BoxShape.circle),
                child: Icon(style.$1, color: style.$2, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.type.label, style: Theme.of(context).textTheme.titleSmall),
                    if (!expanded)
                      if (meal.items.isEmpty)
                        Text('Ничего не добавлено', style: Theme.of(context).textTheme.bodySmall)
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _MealItemsPreview(items: meal.items),
                        ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${meal.calories} ккал', style: Theme.of(context).textTheme.titleSmall),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink300),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: AppSpacing.lg),
                for (var i = 0; i < meal.items.length; i++) ...[
                  _EntryRow(mealId: meal.id, entry: meal.items[i]),
                  if (i < meal.items.length - 1) const SizedBox(height: 8),
                ],
                if (meal.items.isNotEmpty) const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () => showAddFoodMethodSheet(context, mealId: meal.id, mealType: meal.type),
                  child: const AddFoodRow(label: 'Добавить продукт'),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Стопка мини-фото продуктов в свёрнутой карточке приёма пищи — чтобы
/// сразу по превью было видно, что именно добавлено, не разворачивая
/// карточку и не читая список названий текстом.
class _MealItemsPreview extends StatelessWidget {
  const _MealItemsPreview({required this.items});
  final List<MealEntryData> items;

  static const _maxShown = 5;
  static const _size = 22.0;
  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(_maxShown).toList();
    final extra = items.length - shown.length;
    final circles = shown.length + (extra > 0 ? 1 : 0);
    final width = circles == 0 ? 0.0 : (circles - 1) * (_size - _overlap) + _size;
    final borderColor = Theme.of(context).cardTheme.color ?? Colors.white;

    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (_size - _overlap),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 1.5)),
                child: FoodThumbnail(id: shown[i].foodId ?? shown[i].name, imageUrl: shown[i].imageUrl, size: _size, iconSize: 11),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * (_size - _overlap),
              child: Container(
                width: _size,
                height: _size,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.ink100, border: Border.all(color: borderColor, width: 1.5)),
                child: Text('+$extra', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.ink500)),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.mealId, required this.entry});
  final String mealId;
  final MealEntryData entry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => MealEntryDetailSheet(mealId: mealId, entryId: entry.id),
      ),
      child: Row(
        children: [
          FoodThumbnail(id: entry.foodId ?? entry.name, imageUrl: entry.imageUrl, size: 38, iconSize: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text('${entry.grams.toStringAsFixed(0)} г', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text('${entry.calories} ккал', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink300, size: 18),
        ],
      ),
    );
  }
}

/// Детали продукта в приёме пищи — все значения уже посчитаны backend'ом
/// на фактический вес, Flutter только показывает и позволяет поменять
/// граммовку (что снова уходит на backend, а не пересчитывается тут).
class MealEntryDetailSheet extends ConsumerStatefulWidget {
  const MealEntryDetailSheet({super.key, required this.mealId, required this.entryId});
  final String mealId;
  final String entryId;

  @override
  ConsumerState<MealEntryDetailSheet> createState() => _MealEntryDetailSheetState();
}

class _MealEntryDetailSheetState extends ConsumerState<MealEntryDetailSheet> {
  bool _busy = false;

  Future<void> _updateGrams(double grams) async {
    if (grams <= 0) return;
    setState(() => _busy = true);
    try {
      await ref.read(nutritionDayProvider.notifier).updateItemGrams(widget.entryId, grams);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ref.read(nutritionDayProvider.notifier).deleteItem(widget.entryId);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayState = ref.watch(nutritionDayProvider);
    return dayState.when(
      loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(height: 140, child: Center(child: Text('Не удалось загрузить'))),
      data: (summary) {
        final meal = summary.meals.firstWhere((m) => m.id == widget.mealId, orElse: () => summary.meals.first);
        final entryIndex = meal.items.indexWhere((e) => e.id == widget.entryId);
        if (entryIndex == -1) return const SizedBox.shrink();
        final entry = meal.items[entryIndex];

        return Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FoodThumbnail(id: entry.foodId ?? entry.name, imageUrl: entry.imageUrl, size: 64, iconSize: 30),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.name, style: Theme.of(context).textTheme.headlineMedium),
                        Text('${entry.grams.toStringAsFixed(0)} г · ${meal.type.label}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: _statColumn(context, 'Калории', '${entry.calories}')),
                  Expanded(child: _statColumn(context, 'Белки', '${entry.protein.toStringAsFixed(1)} г')),
                  Expanded(child: _statColumn(context, 'Жиры', '${entry.fat.toStringAsFixed(1)} г')),
                  Expanded(child: _statColumn(context, 'Углеводы', '${entry.carbohydrates.toStringAsFixed(1)} г')),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Вес порции', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: _busy || entry.grams <= 10 ? null : () => _updateGrams(entry.grams - 10),
                    icon: const Icon(Icons.remove_rounded),
                    style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
                  ),
                  SizedBox(
                    width: 100,
                    child: _busy
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : Text('${entry.grams.toStringAsFixed(0)} г', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _updateGrams(entry.grams + 10),
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
                  ),
                ],
              ),
              if (entry.fiber > 0 || entry.sugar != null || entry.sodium != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Пищевая ценность порции', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                if (entry.fiber > 0) _nutrientRow(context, 'Клетчатка', '${entry.fiber.toStringAsFixed(1)} г'),
                if (entry.sugar != null) _nutrientRow(context, 'Сахар', '${entry.sugar!.toStringAsFixed(1)} г'),
                if (entry.sodium != null) _nutrientRow(context, 'Натрий', '${entry.sodium!.toStringAsFixed(0)} мг'),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  label: const Text('Удалить из приёма пищи', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statColumn(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _nutrientRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class AddFoodRow extends StatelessWidget {
  const AddFoodRow({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_rounded, size: 16, color: AppColors.green600),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.green600)),
        ],
      ),
    );
  }
}
