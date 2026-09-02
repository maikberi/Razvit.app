import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/workout_session.dart';
import '../../../data/repositories/progress_repository.dart';
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
    final volume = ref.watch(monthlyVolumeProvider);

    final days = switch (_period) {
      _Period.week => 7,
      _Period.month => 30,
      _Period.year => 365,
      _Period.all => 100000,
    };
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final filtered = sessions.where((s) => s.date.isAfter(cutoff)).toList();

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
                  SizedBox(
                    height: 140,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [for (var i = 0; i < volume.length; i++) FlSpot(i.toDouble(), volume[i].volumeKg)],
                            isCurved: true,
                            color: AppColors.green500,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
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
