import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_repository.dart';
import 'add_food_method_sheet.dart';
import 'food_ui.dart';

(IconData, Color, Color) _mealStyle(MealType t) => switch (t) {
      MealType.breakfast => (Icons.free_breakfast_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF4DF)),
      MealType.lunch => (Icons.lunch_dining_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      MealType.dinner => (Icons.dinner_dining_rounded, const Color(0xFF8B5CF6), const Color(0xFFF2ECFE)),
      MealType.snack => (Icons.cookie_rounded, AppColors.green600, AppColors.green50),
    };

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  final Set<MealType> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final meals = ref.watch(mealsProvider);
    final plan = ref.watch(nutritionPlanProvider);
    final water = ref.watch(waterIntakeProvider);
    final waterNotifier = ref.read(waterIntakeProvider.notifier);

    final calories = meals.fold(0, (s, m) => s + m.calories);
    final protein = meals.fold(0.0, (s, m) => s + m.protein);
    final fat = meals.fold(0.0, (s, m) => s + m.fat);
    final carbs = meals.fold(0.0, (s, m) => s + m.carbs);
    final remaining = plan.calorieGoal - calories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Питание'),
        actions: [
          IconButton(onPressed: () => context.push('/notifications'), icon: const Icon(Icons.notifications_none_rounded)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          children: [
            Row(
              children: [
                Text('Сегодня', style: Theme.of(context).textTheme.titleMedium),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink500),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.card,
                  ),
                  child: IconButton(
                    onPressed: () => context.push('/nutrition-stats'),
                    icon: const Icon(Icons.calendar_today_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Row(
                children: [
                  ProgressRing(
                    progress: plan.calorieGoal == 0 ? 0 : (calories / plan.calorieGoal).clamp(0, 1),
                    size: 132,
                    strokeWidth: 11,
                    color: AppColors.green500,
                    trackColor: AppColors.green100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$calories',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text('/ ${plan.calorieGoal} ккал', style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
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
                        _macroLine(context, 'Белки', protein, plan.proteinGoal),
                        const SizedBox(height: 16),
                        _macroLine(context, 'Жиры', fat, plan.fatGoal),
                        const SizedBox(height: 16),
                        _macroLine(context, 'Углеводы', carbs, plan.carbsGoal),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: _QuickAction(icon: Icons.assignment_outlined, label: 'План', onTap: () => context.push('/nutrition-plan'))),
                const SizedBox(width: 8),
                Expanded(child: _QuickAction(icon: Icons.menu_book_outlined, label: 'Рецепты', onTap: () => context.push('/recipes'))),
                const SizedBox(width: 8),
                Expanded(child: _QuickAction(icon: Icons.bar_chart_rounded, label: 'Статистика', onTap: () => context.push('/nutrition-stats'))),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Вода', style: Theme.of(context).textTheme.titleMedium),
                      Text('${(water / 1000).toStringAsFixed(1)} / ${(plan.waterGoalMl / 1000).toStringAsFixed(1)} л', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      for (var i = 0; i < 8; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => waterNotifier.set((i + 1) * 250),
                            child: Icon(
                              Icons.water_drop_rounded,
                              size: 22,
                              color: (i + 1) * 250 <= water ? AppColors.water : AppColors.ink200,
                            ),
                          ),
                        ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => waterNotifier.add(250),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(color: AppColors.green500, shape: BoxShape.circle),
                          child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Приёмы пищи', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final meal in meals) ...[
              _MealSection(
                meal: meal,
                expanded: _expanded.contains(meal.type),
                onToggle: () => setState(() {
                  if (!_expanded.add(meal.type)) _expanded.remove(meal.type);
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _macroLine(BuildContext context, String label, double value, int goal) {
    final done = goal > 0 && value >= goal;
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
            Text('${value.toStringAsFixed(0)} / $goal г', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppColors.green600, size: 20),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal, required this.expanded, required this.onToggle});
  final Meal meal;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final style = _mealStyle(meal.type);
    final summary = meal.entries.map((e) => e.food.name).join(', ');

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
                      Text(
                        summary.isEmpty ? 'Ничего не добавлено' : summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
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
                for (var i = 0; i < meal.entries.length; i++) ...[
                  _EntryRow(mealType: meal.type, entryIndex: i, entry: meal.entries[i]),
                  if (i < meal.entries.length - 1) const SizedBox(height: 8),
                ],
                if (meal.entries.isNotEmpty) const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () => showAddFoodMethodSheet(context, meal.type),
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

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.mealType, required this.entryIndex, required this.entry});
  final MealType mealType;
  final int entryIndex;
  final FoodEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = foodBadgeColor(entry.food.id);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => FoodEntryDetailSheet(mealType: mealType, entryIndex: entryIndex),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.restaurant_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.food.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text('${entry.grams} г', style: Theme.of(context).textTheme.bodySmall),
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

class FoodEntryDetailSheet extends ConsumerStatefulWidget {
  const FoodEntryDetailSheet({super.key, required this.mealType, required this.entryIndex});
  final MealType mealType;
  final int entryIndex;

  @override
  ConsumerState<FoodEntryDetailSheet> createState() => _FoodEntryDetailSheetState();
}

class _FoodEntryDetailSheetState extends ConsumerState<FoodEntryDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final meals = ref.watch(mealsProvider);
    final meal = meals.firstWhere((m) => m.type == widget.mealType);
    if (widget.entryIndex >= meal.entries.length) return const SizedBox.shrink();
    final entry = meal.entries[widget.entryIndex];
    final food = entry.food;
    final color = foodBadgeColor(food.id);
    final ratio = entry.grams / 100;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.restaurant_rounded, color: color, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: Theme.of(context).textTheme.headlineMedium),
                    Text('${entry.grams} г · ${widget.mealType.label}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _statColumn(context, 'Калории', '${(food.caloriesPer100g * ratio).round()}')),
              Expanded(child: _statColumn(context, 'Белки', '${(food.proteinPer100g * ratio).toStringAsFixed(0)} г')),
              Expanded(child: _statColumn(context, 'Жиры', '${(food.fatPer100g * ratio).toStringAsFixed(0)} г')),
              Expanded(child: _statColumn(context, 'Углеводы', '${(food.carbsPer100g * ratio).toStringAsFixed(0)} г')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Вес порции', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: entry.grams > 10
                    ? () => ref.read(mealsProvider.notifier).updateGrams(widget.mealType, widget.entryIndex, entry.grams - 10)
                    : null,
                icon: const Icon(Icons.remove_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
              ),
              SizedBox(width: 100, child: Text('${entry.grams} г', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium)),
              IconButton.filled(
                onPressed: () => ref.read(mealsProvider.notifier).updateGrams(widget.mealType, widget.entryIndex, entry.grams + 10),
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Пищевая ценность на 100 г', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          _nutrientRow(context, 'Калории', '${food.caloriesPer100g} ккал'),
          _nutrientRow(context, 'Белки', '${food.proteinPer100g.toStringAsFixed(1)} г'),
          _nutrientRow(context, 'Жиры', '${food.fatPer100g.toStringAsFixed(1)} г'),
          _nutrientRow(context, 'Углеводы', '${food.carbsPer100g.toStringAsFixed(1)} г'),
          _nutrientRow(context, 'Клетчатка', '${food.fiberPer100g.toStringAsFixed(1)} г'),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(mealsProvider.notifier).removeFood(widget.mealType, widget.entryIndex);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              label: const Text('Удалить из приёма пищи', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
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
