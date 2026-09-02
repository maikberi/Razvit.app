import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/mock/mock_progress.dart';

class WeightChartCard extends StatelessWidget {
  const WeightChartCard({super.key, required this.history, required this.currentWeight});

  final List<WeightEntry> history;
  final double currentWeight;

  @override
  Widget build(BuildContext context) {
    final diff = history.isEmpty ? 0.0 : currentWeight - history.first.weightKg;
    final spots = <FlSpot>[
      for (var i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i].weightKg),
    ];
    final minY = history.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = history.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b) + 2;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Прогресс', actionLabel: 'Подробнее', onAction: () => context.push('/workout-stats')),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Динамика веса', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${currentWeight.toStringAsFixed(0)} кг', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(width: 8),
              Text(
                '${diff <= 0 ? '' : '+'}${diff.toStringAsFixed(1)} кг',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: diff <= 0 ? AppColors.green600 : AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 110,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.green500,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.green500.withValues(alpha: 0.18), AppColors.green500.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('d MMM', 'ru').format(history.first.date), style: Theme.of(context).textTheme.bodySmall),
              Text(DateFormat('d MMM', 'ru').format(history.last.date), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
