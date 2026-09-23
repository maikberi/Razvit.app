import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/nutrition_analytics.dart';
import '../../../data/services/nutrition_api_service.dart';

/// ЭТАП 16: Nutrition Analytics — 7/30/90 дней, вся статистика (средние,
/// goal adherence, дни в цели, графики) приходит одним агрегированным
/// ответом backend'а (GET /nutrition/analytics), Flutter не грузит сырые
/// записи и ничего сам не усредняет — только показывает готовые числа.
class NutritionStatsScreen extends ConsumerStatefulWidget {
  const NutritionStatsScreen({super.key});

  @override
  ConsumerState<NutritionStatsScreen> createState() => _NutritionStatsScreenState();
}

class _NutritionStatsScreenState extends ConsumerState<NutritionStatsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.d7;

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(nutritionAnalyticsProvider(_period));

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика питания'), leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: Row(
                children: [
                  for (final p in AnalyticsPeriod.values) ...[
                    Expanded(
                      child: SelectableChip(dense: true, label: p.label, selected: _period == p, onTap: () => setState(() => _period = p)),
                    ),
                    if (p != AnalyticsPeriod.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: analyticsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          err is ApiException ? err.message : 'Не удалось загрузить статистику',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(nutritionAnalyticsProvider(_period)),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (result) => result.loggedDays == 0
                    ? const EmptyState(
                        emoji: '📊',
                        title: 'Пока нет данных',
                        subtitle: 'Начни отмечать приёмы пищи — здесь появится статистика',
                      )
                    : _AnalyticsContent(result: result),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({required this.result});
  final NutritionAnalyticsResult result;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Залогировано ${result.loggedDays} из ${result.totalDays} дней', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Ср. калории', value: '${result.averages.calories}', unit: 'ккал')),
            const SizedBox(width: 8),
            Expanded(child: _StatTile(label: 'Ср. белок', value: result.averages.protein.toStringAsFixed(0), unit: 'г')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Goal adherence', value: '${result.goalAdherencePercent}', unit: '%', highlight: true)),
            const SizedBox(width: 8),
            Expanded(child: _StatTile(label: 'Days on target', value: '${result.daysOnTarget}', unit: 'из ${result.loggedDays}')),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Калории', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Цель: ${result.calorieGoal} ккал/день', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
              const SizedBox(height: AppSpacing.md),
              _DailyLineChart(days: result.days, valueOf: (d) => d.calories.toDouble(), color: AppColors.green500, targetLine: result.calorieGoal.toDouble()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Белок', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _DailyLineChart(days: result.days, valueOf: (d) => d.protein, color: AppColors.protein, targetLine: null),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Вода', style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${(result.averages.waterMl / 1000).toStringAsFixed(1)} л / ${(result.waterGoalMl / 1000).toStringAsFixed(1)} л',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text('В среднем за день (по дням с записями)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in result.days)
                    Icon(
                      Icons.water_drop_rounded,
                      size: 18,
                      color: d.waterMl >= result.waterGoalMl * 0.8 ? AppColors.water : AppColors.ink200,
                    ),
                ],
              ),
            ],
          ),
        ),
        // Weight-график здесь намеренно нет — в приложении пока нет ни одной
        // персистентной записи веса (только статичное мок-поле в профиле),
        // а постановка задачи просит график веса только "если уже существует".
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.unit, this.highlight = false});
  final String label;
  final String value;
  final String unit;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: highlight ? AppColors.green50 : null,
      shadow: !highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(width: 4),
              Text(unit, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyLineChart extends StatelessWidget {
  const _DailyLineChart({required this.days, required this.valueOf, required this.color, required this.targetLine});
  final List<NutritionAnalyticsDay> days;
  final double Function(NutritionAnalyticsDay) valueOf;
  final Color color;
  final double? targetLine;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                interval: (days.length / 3).clamp(1, double.infinity).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat('d.MM').format(days[i].date), style: const TextStyle(fontSize: 9, color: AppColors.ink400)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), valueOf(days[i]))],
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(show: days.length <= 14),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
            ),
            if (targetLine != null)
              LineChartBarData(
                spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), targetLine!)],
                isCurved: false,
                color: AppColors.ink300,
                barWidth: 1,
                dotData: const FlDotData(show: false),
                dashArray: [4, 4],
              ),
          ],
        ),
      ),
    );
  }
}
