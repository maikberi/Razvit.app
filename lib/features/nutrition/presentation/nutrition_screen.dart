import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_repository.dart';

(IconData, Color, Color) _mealStyle(MealType t) => switch (t) {
      MealType.breakfast => (Icons.free_breakfast_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF4DF)),
      MealType.lunch => (Icons.lunch_dining_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      MealType.dinner => (Icons.dinner_dining_rounded, const Color(0xFF8B5CF6), const Color(0xFFF2ECFE)),
      MealType.snack => (Icons.cookie_rounded, AppColors.green600, AppColors.green50),
    };

class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      appBar: AppBar(title: const Text('Питание')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          children: [
            AppCard(
              color: AppColors.green500,
              shadow: false,
              child: Row(
                children: [
                  ProgressRing(
                    progress: plan.calorieGoal == 0 ? 0 : (calories / plan.calorieGoal).clamp(0, 1),
                    size: 100,
                    strokeWidth: 9,
                    color: Colors.white,
                    trackColor: Colors.white24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          remaining >= 0 ? '$remaining' : '${-remaining}',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          remaining >= 0 ? 'осталось ккал' : 'сверх плана',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
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
                        const SizedBox(height: 8),
                        _macroLine(context, 'Жиры', fat, plan.fatGoal),
                        const SizedBox(height: 8),
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
                              size: 24,
                              color: (i + 1) * 250 <= water ? AppColors.water : AppColors.ink200,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(onPressed: () => waterNotifier.add(250), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('250 мл')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(onPressed: () => waterNotifier.add(500), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('500 мл')),
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
              _MealSection(meal: meal),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _macroLine(BuildContext context, String label, double value, int goal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${value.toStringAsFixed(0)} / $goal г', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: goal == 0 ? 0 : (value / goal).clamp(0, 1),
            minHeight: 5,
            backgroundColor: Colors.white24,
            color: Colors.white,
          ),
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

class _MealSection extends ConsumerWidget {
  const _MealSection({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _mealStyle(meal.type);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/add-food/${meal.type.name}'),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: style.$3, shape: BoxShape.circle),
                  child: Icon(style.$1, color: style.$2, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meal.type.label, style: Theme.of(context).textTheme.titleSmall),
                      Text(meal.time, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text('${meal.calories} ккал', style: Theme.of(context).textTheme.titleSmall),
                const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
              ],
            ),
          ),
          if (meal.entries.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            for (var i = 0; i < meal.entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${meal.entries[i].food.name} · ${meal.entries[i].grams} г', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Text('${meal.entries[i].calories} ккал', style: Theme.of(context).textTheme.bodySmall),
                    IconButton(
                      onPressed: () => ref.read(mealsProvider.notifier).removeFood(meal.type, i),
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.ink400),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => context.push('/add-food/${meal.type.name}'),
              child: AddFoodRow(label: 'Добавить продукт'),
            ),
          ],
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
        border: Border.all(color: Theme.of(context).dividerColor, style: BorderStyle.solid),
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
