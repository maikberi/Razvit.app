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

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  bool _editMode = false;

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
                IconButton(
                  onPressed: () => context.push('/workout-calendar'),
                  icon: const Icon(Icons.calendar_today_outlined, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
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
                        const SizedBox(height: 10),
                        _macroLine(context, 'Жиры', fat, plan.fatGoal),
                        const SizedBox(height: 10),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Приёмы пищи', style: Theme.of(context).textTheme.titleLarge),
                _LinkText(label: _editMode ? 'Готово' : 'Изменить', onTap: () => setState(() => _editMode = !_editMode)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final meal in meals) ...[
              _MealSection(meal: meal, editMode: _editMode),
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
        Icon(done ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Text('${value.toStringAsFixed(0)} / $goal г', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.green600)),
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
  const _MealSection({required this.meal, required this.editMode});
  final Meal meal;
  final bool editMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _mealStyle(meal.type);
    final summary = meal.entries.map((e) => e.food.name).join(', ');

    return AppCard(
      onTap: editMode ? null : () => context.push('/add-food/${meal.type.name}'),
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
              if (!editMode) const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
            ],
          ),
          if (editMode && meal.entries.isNotEmpty) ...[
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
          ],
          if (editMode) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => context.push('/add-food/${meal.type.name}'),
              child: const AddFoodRow(label: 'Добавить продукт'),
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
