import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/workout_session.dart';
import '../../../data/repositories/workout_repository.dart';

enum _Period { week, month, year, all }

class WorkoutStatsScreen extends ConsumerStatefulWidget {
  const WorkoutStatsScreen({super.key});

  @override
  ConsumerState<WorkoutStatsScreen> createState() => _WorkoutStatsScreenState();
}

class _WorkoutStatsScreenState extends ConsumerState<WorkoutStatsScreen> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(workoutSessionsProvider).where((s) => s.status == SessionStatus.done).toList();

    final days = switch (_period) {
      _Period.week => 7,
      _Period.month => 30,
      _Period.year => 365,
      _Period.all => 100000,
    };
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final filtered = sessions.where((s) => s.date.isAfter(cutoff)).toList()..sort((a, b) => a.date.compareTo(b.date));

    final totalMinutes = filtered.fold<int>(0, (s, w) => s + w.durationMinutes);
    final totalVolume = filtered.fold<double>(0, (s, w) => s + w.volumeKg);
    final avgDuration = filtered.isEmpty ? 0 : totalMinutes ~/ filtered.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика тренировок'), leading: const BackButton()),
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
            Row(
              children: [
                Expanded(child: _bigStat(context, '${filtered.length}', 'Тренировок')),
                const SizedBox(width: 10),
                Expanded(child: _bigStat(context, '$avgDuration мин', 'Средняя длительность')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Объём тренировок', style: Theme.of(context).textTheme.bodySmall),
                  Text('${totalVolume.round()} кг', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: AppSpacing.md),
                  if (filtered.isEmpty)
                    const SizedBox(height: 100, child: Center(child: Text('Нет тренировок за этот период')))
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
                              spots: [for (var i = 0; i < filtered.length; i++) FlSpot(i.toDouble(), filtered[i].volumeKg)],
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
            Text('Силовые показатели', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _StrengthRow(exerciseId: 'bench_press', title: 'Жим лёжа'),
            const SizedBox(height: 8),
            _StrengthRow(exerciseId: 'squat', title: 'Присед'),
            const SizedBox(height: 8),
            _StrengthRow(exerciseId: 'deadlift', title: 'Становая'),
          ],
        ),
      ),
    );
  }

  Widget _bigStat(BuildContext context, String value, String label) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StrengthRow extends ConsumerWidget {
  const _StrengthRow({required this.exerciseId, required this.title});
  final String exerciseId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(exerciseHistoryProvider(exerciseId));
    if (history.isEmpty) return const SizedBox.shrink();
    final current = history.last.weightKg;
    final prev = history.length > 1 ? history[history.length - 2].weightKg : current;
    final diff = current - prev;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                Text('${current.toStringAsFixed(0)} кг', style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)} кг',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: diff >= 0 ? AppColors.green600 : AppColors.error),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 50,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i].weightKg)],
                    isCurved: true,
                    color: AppColors.green500,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
