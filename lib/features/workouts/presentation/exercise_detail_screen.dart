import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loop_video.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/mock/mock_exercises.dart';
import '../../../data/models/exercise.dart';
import '../../../data/repositories/workout_repository.dart';

enum _Period { week, month, m3, m6, year, all }

extension on _Period {
  String get label => switch (this) {
        _Period.week => 'Неделя',
        _Period.month => 'Месяц',
        _Period.m3 => '3 месяца',
        _Period.m6 => '6 месяцев',
        _Period.year => 'Год',
        _Period.all => 'Всё время',
      };

  int? get days => switch (this) {
        _Period.week => 7,
        _Period.month => 30,
        _Period.m3 => 90,
        _Period.m6 => 180,
        _Period.year => 365,
        _Period.all => null,
      };
}

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  _Period _period = _Period.all;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _favorite = exerciseById(widget.exerciseId).isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    final exercise = exerciseById(widget.exerciseId);
    final history = ref.watch(exerciseHistoryProvider(widget.exerciseId));

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                    Expanded(
                      child: Text(exercise.name, style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _favorite = !_favorite),
                      icon: Icon(_favorite ? Icons.star_rounded : Icons.star_border_rounded, color: _favorite ? AppColors.warning : AppColors.ink400),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: exercise.videoAsset != null
                    ? LoopVideo(assetPath: exercise.videoAsset!)
                    : Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(color: AppColors.ink800, borderRadius: BorderRadius.circular(AppRadius.lg)),
                        child: const Center(child: Icon(Icons.fitness_center_rounded, color: Colors.white38, size: 56)),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TagBadge(label: exercise.primaryMuscle.label),
                    TagBadge(label: exercise.equipment, color: AppColors.ink700),
                    TagBadge(label: exercise.difficulty.label, color: AppColors.info),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const TabBar(
                isScrollable: true,
                labelColor: AppColors.green600,
                unselectedLabelColor: AppColors.ink500,
                indicatorColor: AppColors.green500,
                tabs: [
                  Tab(text: 'Инструкция'),
                  Tab(text: 'Ошибки'),
                  Tab(text: 'Мышцы'),
                  Tab(text: 'Советы'),
                  Tab(text: 'История'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _TextListTab(items: exercise.instructions, emptyText: 'Инструкция скоро появится'),
                    _TextListTab(items: exercise.mistakes, emptyText: 'Частых ошибок не выявлено'),
                    _MusclesTab(exercise: exercise),
                    _TextListTab(items: exercise.tips, emptyText: 'Советы скоро появятся'),
                    _HistoryTab(
                      history: history,
                      period: _period,
                      onPeriodChanged: (p) => setState(() => _period = p),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextListTab extends StatelessWidget {
  const _TextListTab({required this.items, required this.emptyText});
  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(emoji: '📝', title: emptyText);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppColors.green500, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(items[i], style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _MusclesTab extends StatelessWidget {
  const _MusclesTab({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Основная мышца', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(exercise.primaryMuscle.label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        if (exercise.secondaryMuscles.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Второстепенные мышцы', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final m in exercise.secondaryMuscles) TagBadge(label: m.label, color: AppColors.ink700)]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.history, required this.period, required this.onPeriodChanged});
  final List<ExerciseHistoryEntry> history;
  final _Period period;
  final ValueChanged<_Period> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyState(emoji: '📈', title: 'Пока нет истории', subtitle: 'Выполни это упражнение на тренировке, чтобы увидеть прогресс');
    }

    final cutoff = period.days == null ? null : DateTime.now().subtract(Duration(days: period.days!));
    final filtered = cutoff == null ? history : history.where((e) => e.date.isAfter(cutoff)).toList();
    final display = filtered.isEmpty ? history : filtered;
    final lastEntry = history.last;
    final maxWeight = history.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (lastEntry.isPersonalRecord)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              color: AppColors.green500,
              shadow: false,
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Новый личный рекорд!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        Text('${maxWeight.toStringAsFixed(0)} кг', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _Period.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = _Period.values[i];
              return SelectableChip(label: p.label, selected: period == p, onTap: () => onPeriodChanged(p));
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < display.length; i++) FlSpot(i.toDouble(), display[i].weightKg)],
                    isCurved: true,
                    color: AppColors.green500,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('История подходов', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in display.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Text(DateFormat('d MMMM', 'ru').format(entry.date), style: Theme.of(context).textTheme.bodyMedium)),
                  Text('${entry.weightKg.toStringAsFixed(0)} кг × ${entry.reps}', style: Theme.of(context).textTheme.titleSmall),
                  if (entry.isPersonalRecord) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 18),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
