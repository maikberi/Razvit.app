import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/models/exercise.dart';
import '../../../../data/models/workout.dart';
import '../../../../data/repositories/workout_repository.dart';
import '../../widgets/program_card.dart';

class MyProgramTab extends ConsumerWidget {
  const MyProgramTab({super.key, this.onCategoryTap});

  final ValueChanged<MuscleGroup>? onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayWorkoutProvider);
    final programs = ref.watch(allProgramsProvider);
    final records = ref.watch(personalRecordsProvider);
    final exercises = ref.watch(exerciseCatalogProvider).where((e) => e.isFavorite).take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _TodayCard(title: today.title, exercises: today.exercises.length, minutes: today.estimatedDuration.inMinutes, volume: today.estimatedVolumeKg),
        const SizedBox(height: AppSpacing.lg),
        Text('Прогресс недели', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: const LinearProgressIndicator(value: 4 / 5, minHeight: 8, backgroundColor: AppColors.ink100),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('4 / 5', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Категории', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: MuscleGroup.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final group = MuscleGroup.values[i];
              return ActionChip(
                onPressed: () => onCategoryTap?.call(group),
                label: Text(group.label),
                backgroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: 'Мои программы'),
        const SizedBox(height: AppSpacing.sm),
        for (final p in programs) ...[
          ProgramCard(program: p, onTap: () => _showProgramSheet(context, p)),
          const SizedBox(height: AppSpacing.sm),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/create-program'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Создать свою программу'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: 'Рекомендуемые упражнения'),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: exercises.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final e = exercises[i];
              return _ExerciseThumb(exercise: e);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: 'Личные рекорды'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < records.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  child: Column(
                    children: [
                      Text('${records[i].weightKg.toStringAsFixed(0)} кг', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(records[i].exerciseName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          color: AppColors.green50,
          shadow: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.green600),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Совет от AI-наставника', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Ты прогрессируешь! Не забывай про восстановление и растяжку после тренировок.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showProgramSheet(BuildContext context, WorkoutProgram program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProgramSheet(program: program),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.title, required this.exercises, required this.minutes, required this.volume});
  final String title;
  final int exercises;
  final int minutes;
  final double volume;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сегодня', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _stat(context, Icons.fitness_center_rounded, '$exercises упражнений'),
              const SizedBox(width: 16),
              _stat(context, Icons.timer_outlined, '$minutes минут'),
            ],
          ),
          const SizedBox(height: 6),
          _stat(context, Icons.bar_chart_rounded, '${volume.round()} кг объём'),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/workout-session'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [Text('Начать тренировку'), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, size: 18)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.ink500),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ExerciseThumb extends StatelessWidget {
  const _ExerciseThumb({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/exercise/${exercise.id}'),
      child: SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 84,
              width: 108,
              decoration: BoxDecoration(
                color: AppColors.ink800,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.fitness_center_rounded, color: Colors.white54, size: 30),
            ),
            const SizedBox(height: 6),
            Text(exercise.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
            Text(exercise.primaryMuscle.label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ProgramSheet extends StatelessWidget {
  const _ProgramSheet({required this.program});
  final WorkoutProgram program;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.ink200, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: AppSpacing.lg),
            Text(program.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('${program.goal.label} · ${program.level.label} · ${program.totalWeeks} недель', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
            const SizedBox(height: AppSpacing.lg),
            for (final day in program.days)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center_rounded, color: AppColors.green600, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(day.title, style: Theme.of(context).textTheme.bodyLarge)),
                      Text('${day.exercises.length} упр.', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/workout-session');
                },
                child: const Text('Начать тренировку'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
