import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loop_video.dart';
import '../../../data/models/exercise.dart';
import '../../../data/repositories/workout_repository.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  ConsumerState<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  double _weight = 0;
  int _reps = 0;
  int _lastExerciseIndex = -1;
  int _lastSetIndex = -1;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(activeWorkoutProvider.notifier);
      if (ref.read(activeWorkoutProvider) == null) {
        notifier.start(ref.read(todayWorkoutProvider));
      }
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final s = ref.read(activeWorkoutProvider);
        if (s != null && mounted) setState(() => _elapsed = DateTime.now().difference(s.startedAt));
      });
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _syncDefaults(ActiveWorkoutState state) {
    if (state.exerciseIndex != _lastExerciseIndex || state.setIndex != _lastSetIndex) {
      _lastExerciseIndex = state.exerciseIndex;
      _lastSetIndex = state.setIndex;
      _weight = state.currentExercise.weightKg;
      final label = state.currentExercise.repsLabel;
      _reps = int.tryParse(label.split('–').last.replaceAll(RegExp(r'[^0-9]'), '')) ??
          int.tryParse(label.split('–').first) ??
          10;
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeWorkoutProvider);

    ref.listen(activeWorkoutProvider, (prev, next) {
      if (next != null && next.isFinished) {
        context.pushReplacement('/workout-session/complete');
      }
    });

    if (state == null) {
      return const Scaffold(backgroundColor: AppColors.ink900, body: Center(child: CircularProgressIndicator(color: AppColors.green500)));
    }

    _syncDefaults(state);

    final day = state.day;
    final exercise = state.currentExercise;
    final completedSets = state.logsFor(state.exerciseIndex);

    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _confirmExit(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(day.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('${state.exerciseIndex + 1} / ${day.exercises.length} упражнений', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(_fmt(_elapsed), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.exercise.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    Text(exercise.exercise.primaryMuscle.label, style: const TextStyle(color: Colors.white54)),
                    const SizedBox(height: AppSpacing.md),
                    exercise.exercise.videoAsset != null
                        ? LoopVideo(assetPath: exercise.exercise.videoAsset!, posterAssetPath: exercise.exercise.videoPosterAsset)
                        : Container(
                            height: 200,
                            decoration: BoxDecoration(color: AppColors.darkSurfaceElevated, borderRadius: BorderRadius.circular(AppRadius.lg)),
                            child: const Center(
                              child: Icon(Icons.fitness_center_rounded, color: Colors.white38, size: 56),
                            ),
                          ),
                    const SizedBox(height: AppSpacing.lg),
                    if (state.isResting)
                      _RestPanel(seconds: state.restRemaining, total: exercise.restSeconds, onSkip: () => ref.read(activeWorkoutProvider.notifier).skipRest())
                    else
                      _SetPanel(
                        setNumber: state.setIndex + 1,
                        totalSets: exercise.sets,
                        weight: _weight,
                        reps: _reps,
                        restLabel: exercise.restLabel,
                        onWeightChanged: (v) => setState(() => _weight = v),
                        onRepsChanged: (v) => setState(() => _reps = v),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('История подходов', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < exercise.sets; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SetHistoryRow(
                          index: i + 1,
                          done: i < completedSets.length,
                          isCurrent: i == completedSets.length && !state.isResting,
                          weight: i < completedSets.length ? completedSets[i].weightKg : exercise.weightKg,
                          reps: i < completedSets.length ? completedSets[i].reps : null,
                          repsLabel: exercise.repsLabel,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!state.isResting)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(activeWorkoutProvider.notifier).completeSet(weightKg: _weight, reps: _reps);
                        },
                        child: const Text('Завершить подход'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.read(activeWorkoutProvider.notifier).skipExercise(),
                      child: const Text('Пропустить упражнение', style: TextStyle(color: Colors.white60)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Прервать тренировку?'),
        content: const Text('Прогресс этой тренировки не будет сохранён.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              ref.read(activeWorkoutProvider.notifier).finish();
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('Прервать'),
          ),
        ],
      ),
    );
  }
}

class _SetPanel extends StatelessWidget {
  const _SetPanel({
    required this.setNumber,
    required this.totalSets,
    required this.weight,
    required this.reps,
    required this.restLabel,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });

  final int setNumber;
  final int totalSets;
  final double weight;
  final int reps;
  final String restLabel;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.darkSurfaceElevated, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Подход $setNumber из $totalSets', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _NumberStepper(label: 'Вес (кг)', value: weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1), onInc: () => onWeightChanged(weight + 2.5), onDec: () => onWeightChanged((weight - 2.5).clamp(0, 500))),),
              const SizedBox(width: 10),
              Expanded(child: _NumberStepper(label: 'Повторения', value: '$reps', onInc: () => onRepsChanged(reps + 1), onDec: () => onRepsChanged((reps - 1).clamp(0, 100)))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Отдых', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.ink900, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Text(restLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({required this.label, required this.value, required this.onInc, required this.onDec});
  final String label;
  final String value;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniButton(Icons.remove_rounded, onDec),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            _miniButton(Icons.add_rounded, onInc),
          ],
        ),
      ],
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(color: AppColors.ink900, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _RestPanel extends StatelessWidget {
  const _RestPanel({required this.seconds, required this.total, required this.onSkip});
  final int seconds;
  final int total;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : 1 - (seconds / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(color: AppColors.darkSurfaceElevated, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        children: [
          const Text('Отдых', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(value: progress, strokeWidth: 8, backgroundColor: AppColors.ink900, color: AppColors.green500),
              ),
              Text('$seconds', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onSkip,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30)),
            child: const Text('Пропустить отдых'),
          ),
        ],
      ),
    );
  }
}

class _SetHistoryRow extends StatelessWidget {
  const _SetHistoryRow({
    required this.index,
    required this.done,
    required this.isCurrent,
    required this.weight,
    required this.reps,
    required this.repsLabel,
  });

  final int index;
  final bool done;
  final bool isCurrent;
  final double weight;
  final int? reps;
  final String repsLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.green500.withValues(alpha: 0.12) : AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isCurrent ? Border.all(color: AppColors.green500) : null,
      ),
      child: Row(
        children: [
          Text('$index', style: const TextStyle(color: Colors.white60)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              done ? '${weight.toStringAsFixed(0)} кг × $reps' : '${weight.toStringAsFixed(0)} кг × $repsLabel',
              style: TextStyle(color: done ? Colors.white : Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
          if (done)
            const Icon(Icons.check_circle_rounded, color: AppColors.green500, size: 18)
          else if (isCurrent)
            const Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 18),
        ],
      ),
    );
  }
}
