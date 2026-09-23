import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/models/exercise.dart';
import '../../../../data/models/workout.dart';
import '../../../../data/models/workout_session.dart';
import '../../../../data/repositories/workout_repository.dart';
import '../../widgets/program_card.dart';
import '../widgets/exercise_media.dart' as media;

IconData _muscleIcon(MuscleGroup g) => switch (g) {
      MuscleGroup.chest => Icons.fitness_center_rounded,
      MuscleGroup.back => Icons.rowing_rounded,
      MuscleGroup.legs => Icons.directions_walk_rounded,
      MuscleGroup.shoulders => Icons.accessibility_new_rounded,
      MuscleGroup.arms => Icons.sports_gymnastics_rounded,
      MuscleGroup.abs => Icons.self_improvement_rounded,
      MuscleGroup.cardio => Icons.favorite_rounded,
    };

class MyProgramTab extends ConsumerWidget {
  const MyProgramTab({super.key, this.onCategoryTap});

  final ValueChanged<MuscleGroup>? onCategoryTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayWorkoutProvider);
    final programs = ref.watch(allProgramsProvider);
    final records = ref.watch(personalRecordsProvider);
    final catalog = ref.watch(exerciseCatalogProvider);
    final exercises = catalog.where((e) => e.isFavorite).take(4).toList();

    final activeProgram = ref.watch(activeProgramProvider);
    final sessions = ref.watch(workoutSessionsProvider);
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final doneThisWeek = sessions.where((s) => s.status == SessionStatus.done && !s.date.isBefore(startOfWeek)).length;
    final targetPerWeek = activeProgram.trainingDays.isEmpty ? 1 : activeProgram.trainingDays.length;
    final weekProgress = (doneThisWeek / targetPerWeek).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _TodayCard(title: today.title, exercises: today.exercises.length, minutes: today.estimatedDuration.inMinutes, volume: today.estimatedVolumeKg),
        const SizedBox(height: AppSpacing.xl),
        Text('Прогресс недели', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(value: weekProgress, minHeight: 8, backgroundColor: Theme.of(context).dividerColor),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 48,
                child: Text('$doneThisWeek / $targetPerWeek', textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Категории', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: MuscleGroup.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) {
              final group = MuscleGroup.values[i];
              return _CategoryChip(group: group, onTap: () => onCategoryTap?.call(group));
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
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
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: 'Рекомендуемые упражнения'),
        const SizedBox(height: AppSpacing.sm),
        if (exercises.isEmpty)
          Text(
            'Отмечай упражнения звёздочкой в каталоге — они появятся здесь',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
          )
        else
          SizedBox(
            height: 132,
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
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: 'Личные рекорды'),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < records.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: 10),
                  onTap: () {
                    final match = catalog.where((e) => e.name == records[i].exerciseName);
                    if (match.isNotEmpty) context.push('/exercise/${match.first.id}');
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${records[i].weightKg.toStringAsFixed(0)} кг', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        records[i].exerciseName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
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

/// Карточка "Сегодня" — главная точка входа в раздел, поэтому сделана
/// заметнее остальных: мягкий зелёный градиент вместо обычной белой
/// карточки, статы вынесены в отдельные "пилюли" вместо мелких иконок
/// в строку (легче считать глазами, ровнее выглядит на любой ширине).
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.title, required this.exercises, required this.minutes, required this.volume});
  final String title;
  final int exercises;
  final int minutes;
  final double volume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.green50, AppColors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.green100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сегодня', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.green700, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(icon: Icons.fitness_center_rounded, label: '$exercises упражнений'),
              _StatPill(icon: Icons.timer_outlined, label: '$minutes мин'),
              _StatPill(icon: Icons.bar_chart_rounded, label: '${volume.round()} кг'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.green700),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink700)),
        ],
      ),
    );
  }
}

/// Фильтр по группе мышц — иконка в спокойном зелёном круге + подпись,
/// вместо стандартного ActionChip (тот не вписывался в общий визуальный
/// язык остального экрана).
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.group, required this.onTap});
  final MuscleGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: AppColors.green50, shape: BoxShape.circle),
              child: Icon(_muscleIcon(group), color: AppColors.green700, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              group.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseThumb extends StatelessWidget {
  const _ExerciseThumb({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/exercise/${exercise.id}', extra: exercise),
      child: SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            media.ExerciseThumb(exercise: exercise, size: 84),
            const SizedBox(height: 8),
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
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.ink200, borderRadius: BorderRadius.circular(2))),
            ),
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
