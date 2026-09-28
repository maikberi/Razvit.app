import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_emoji.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/workout_session.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../data/services/workout_api_service.dart';

class WorkoutSessionCompleteScreen extends ConsumerStatefulWidget {
  const WorkoutSessionCompleteScreen({super.key});

  @override
  ConsumerState<WorkoutSessionCompleteScreen> createState() => _WorkoutSessionCompleteScreenState();
}

class _WorkoutSessionCompleteScreenState extends ConsumerState<WorkoutSessionCompleteScreen> {
  bool _saving = false;

  Future<void> _finish(ActiveWorkoutState state, Duration duration, int calories) async {
    setState(() => _saving = true);
    try {
      // Сохраняем факт тренировки на backend — раньше "Готово" просто
      // сбрасывало activeWorkoutProvider (in-memory), и вся тренировка,
      // календарь и статистика по ней исчезали при следующем открытии.
      await ref.read(workoutApiServiceProvider).createSession(
            programDayId: state.day.id,
            date: state.startedAt,
            title: state.day.title,
            status: SessionStatus.done,
            durationMinutes: duration.inMinutes,
            calories: calories,
            exerciseLogs: state.exerciseLogs,
          );
      ref.invalidate(workoutSessionsProvider);
      if (!mounted) return;
      ref.read(activeWorkoutProvider.notifier).finish();
      context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить тренировку: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeWorkoutProvider);

    if (state == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: () => context.go('/home'), child: const Text('На главную')),
        ),
      );
    }

    final duration = DateTime.now().difference(state.startedAt);
    final calories = (state.totalVolume * 0.028).round().clamp(120, 900);
    final totalSets = state.totalCompletedSets;
    final totalReps = state.logs.values.fold<int>(0, (s, l) => s + l.fold(0, (a, b) => a + b.reps));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              const AnimatedEmoji('🔥', fontSize: 48),
              const SizedBox(height: AppSpacing.md),
              Text('Тренировка завершена!', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
              Text(state.day.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.ink500)),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _stat(context, '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}', 'Время')),
                          const SizedBox(width: 10),
                          Expanded(child: _stat(context, '$calories', 'Ккал')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _stat(context, '${state.totalVolume.round()}', 'кг объём')),
                          const SizedBox(width: 10),
                          Expanded(child: _stat(context, '${state.day.exercises.length}', 'Упражнений')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _stat(context, '$totalSets', 'Подходов')),
                          const SizedBox(width: 10),
                          Expanded(child: _stat(context, '$totalReps', 'Повторений')),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Что было сделано', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: AppSpacing.sm),
                            for (var i = 0; i < state.day.exercises.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppColors.green500, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(state.day.exercises[i].exercise.name, style: Theme.of(context).textTheme.bodyMedium)),
                                    Text('${state.logsFor(i).length} подх.', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _finish(state, duration, calories),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Готово'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
