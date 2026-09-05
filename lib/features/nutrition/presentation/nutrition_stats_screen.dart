import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/mock/mock_nutrition_history.dart';
import '../../../data/repositories/nutrition_repository.dart';

enum _Period { week, month, year, all }

class NutritionStatsScreen extends ConsumerStatefulWidget {
  const NutritionStatsScreen({super.key});

  @override
  ConsumerState<NutritionStatsScreen> createState() => _NutritionStatsScreenState();
}

class _NutritionStatsScreenState extends ConsumerState<NutritionStatsScreen> {
  _Period _period = _Period.week;

  @override
  Widget build(BuildContext context) {
    final meals = ref.watch(mealsProvider);
    final plan = ref.watch(nutritionPlanProvider);
    final water = ref.watch(waterIntakeProvider);
    final history = ref.watch(nutritionHistoryProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayCalories = meals.fold(0, (s, m) => s + m.calories);
    final todayProtein = meals.fold(0.0, (s, m) => s + m.protein);
    final todayFat = meals.fold(0.0, (s, m) => s + m.fat);
    final todayCarbs = meals.fold(0.0, (s, m) => s + m.carbs);
    final todayLog = NutritionDayLog(date: today, calories: todayCalories, protein: todayProtein, fat: todayFat, carbs: todayCarbs, waterMl: water);

    final combined = [...history, todayLog]..sort((a, b) => a.date.compareTo(b.date));
    final days = switch (_period) {
      _Period.week => 7,
      _Period.month => 30,
      _Period.year => 365,
      _Period.all => 100000,
    };
    final cutoff = today.subtract(Duration(days: days));
    final filtered = combined.where((d) => !d.date.isBefore(cutoff)).toList();

    final avgCalories = filtered.isEmpty ? 0 : filtered.fold(0, (s, d) => s + d.calories) ~/ filtered.length;
    final protein = filtered.fold(0.0, (s, d) => s + d.protein);
    final fat = filtered.fold(0.0, (s, d) => s + d.fat);
    final carbs = filtered.fold(0.0, (s, d) => s + d.carbs);
    final total = protein + fat + carbs;
    final avgWaterMl = filtered.isEmpty ? 0 : filtered.fold(0, (s, d) => s + d.waterMl) ~/ filtered.length;

    final last7 = combined.length <= 7 ? combined : combined.sublist(combined.length - 7);

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика питания'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                for (final p in _Period.values) ...[
                  Expanded(
                    child: SelectableChip(
                      dense: true,
                      label: switch (p) {
                        _Period.week => 'Неделя',
                        _Period.month => 'Месяц',
                        _Period.year => 'Год',
                        _Period.all => 'Всё время',
                      },
                      selected: _period == p,
                      onTap: () => setState(() => _period = p),
                    ),
                  ),
                  if (p != _Period.all) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Калорийность', style: Theme.of(context).textTheme.bodySmall),
                  Text('$avgCalories ккал', style: Theme.of(context).textTheme.headlineLarge),
                  Text('Среднее за день', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  if (filtered.isEmpty)
                    const SizedBox(height: 100, child: Center(child: Text('Нет данных за этот период')))
                  else
                    SizedBox(
                      height: 140,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                interval: (filtered.length / 3).clamp(1, double.infinity).ceilToDouble(),
                                getTitlesWidget: (value, meta) {
                                  final i = value.round();
                                  if (i < 0 || i >= filtered.length) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(DateFormat('d.MM').format(filtered[i].date), style: const TextStyle(fontSize: 9, color: AppColors.ink400)),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [for (var i = 0; i < filtered.length; i++) FlSpot(i.toDouble(), filtered[i].calories.toDouble())],
                              isCurved: true,
                              color: AppColors.green500,
                              barWidth: 3,
                              dotData: FlDotData(show: filtered.length <= 14),
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
                  if (total == 0)
                    const EmptyState(emoji: '🍽️', title: 'Нет данных', subtitle: 'За этот период питание не отслеживалось')
                  else
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
                  Text('${(avgWaterMl / 1000).toStringAsFixed(1)} л / ${(plan.waterGoalMl / 1000).toStringAsFixed(1)} л', style: Theme.of(context).textTheme.headlineMedium),
                  Text('В среднем за день', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      for (final d in last7)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.water_drop_rounded, size: 20, color: d.waterMl >= plan.waterGoalMl * 0.8 ? AppColors.water : AppColors.ink200),
                        ),
                    ],
                  ),
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
