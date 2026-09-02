import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/repositories/nutrition_repository.dart';

class NutritionStatsScreen extends ConsumerStatefulWidget {
  const NutritionStatsScreen({super.key});

  @override
  ConsumerState<NutritionStatsScreen> createState() => _NutritionStatsScreenState();
}

class _NutritionStatsScreenState extends ConsumerState<NutritionStatsScreen> {
  int _periodIndex = 0;
  static const _periods = ['Неделя', 'Месяц', 'Год', 'Всё время'];

  @override
  Widget build(BuildContext context) {
    final meals = ref.watch(mealsProvider);
    final plan = ref.watch(nutritionPlanProvider);
    final water = ref.watch(waterIntakeProvider);

    final protein = meals.fold(0.0, (s, m) => s + m.protein);
    final fat = meals.fold(0.0, (s, m) => s + m.fat);
    final carbs = meals.fold(0.0, (s, m) => s + m.carbs);
    final total = protein + fat + carbs;

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика питания'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                for (var i = 0; i < _periods.length; i++) ...[
                  Expanded(child: SelectableChip(dense: true, label: _periods[i], selected: _periodIndex == i, onTap: () => setState(() => _periodIndex = i))),
                  if (i != _periods.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Калорийность', style: Theme.of(context).textTheme.bodySmall),
                  Text('${plan.calorieGoal - 120} ккал', style: Theme.of(context).textTheme.headlineLarge),
                  Text('Среднее за день', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 120,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [FlSpot(0, 2020), FlSpot(1, 2150), FlSpot(2, 1980), FlSpot(3, 2260), FlSpot(4, 2100), FlSpot(5, 2300), FlSpot(6, 2180)],
                            isCurved: true,
                            color: AppColors.green500,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: AppColors.green500.withValues(alpha: 0.12)),
                          ),
                        ],
                      ),
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
                  Text('Баланс БЖУ', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 30,
                            sections: [
                              PieChartSectionData(value: protein, color: AppColors.protein, showTitle: false, radius: 20),
                              PieChartSectionData(value: fat, color: AppColors.fat, showTitle: false, radius: 20),
                              PieChartSectionData(value: carbs, color: AppColors.carbs, showTitle: false, radius: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _legend(context, AppColors.protein, 'Белки', protein, total),
                            const SizedBox(height: 8),
                            _legend(context, AppColors.fat, 'Жиры', fat, total),
                            const SizedBox(height: 8),
                            _legend(context, AppColors.carbs, 'Углеводы', carbs, total),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Вода', style: Theme.of(context).textTheme.titleMedium),
                  Text('${(water / 1000).toStringAsFixed(1)} л / ${(plan.waterGoalMl / 1000).toStringAsFixed(1)} л', style: Theme.of(context).textTheme.headlineMedium),
                  Text('В среднем за день', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [for (var i = 0; i < 8; i++) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.water_drop_rounded, size: 20, color: i < 6 ? AppColors.water : AppColors.ink200))]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label, double value, double total) {
    final percent = total == 0 ? 0 : (value / total * 100).round();
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Text('${value.toStringAsFixed(0)} г ($percent%)', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
