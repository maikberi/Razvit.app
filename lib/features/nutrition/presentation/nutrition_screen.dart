import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_repository.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Питание'),
        actions: [
          IconButton(onPressed: () => context.push('/nutrition-plan'), icon: const Icon(Icons.assignment_outlined)),
          IconButton(onPressed: () => context.push('/recipes'), icon: const Icon(Icons.menu_book_outlined)),
          IconButton(onPressed: () => context.push('/nutrition-stats'), icon: const Icon(Icons.bar_chart_rounded)),
        ],
      ),
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
                    progress: plan.calorieGoal == 0 ? 0 : calories / plan.calorieGoal,
                    size: 100,
                    strokeWidth: 9,
                    color: Colors.white,
                    trackColor: Colors.white24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$calories', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('/ ${plan.calorieGoal} ккал', style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                          child: Icon(
                            Icons.water_drop_rounded,
                            size: 22,
                            color: (i + 1) * 250 <= water ? AppColors.water : AppColors.ink200,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      OutlinedButton(onPressed: () => waterNotifier.add(250), child: const Text('+250 мл')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () => waterNotifier.add(500), child: const Text('+500 мл')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Приёмы пищи', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
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

class _MealSection extends StatelessWidget {
  const _MealSection({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/add-food/${meal.type.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(meal.type.label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(width: 6),
                    Text(meal.time, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text('${meal.calories} ккал', style: Theme.of(context).textTheme.titleSmall),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
            ],
          ),
          if (meal.entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final entry in meal.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('${entry.food.name} · ${entry.grams} г', style: Theme.of(context).textTheme.bodyMedium)),
                    Text('${entry.calories} ккал', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
