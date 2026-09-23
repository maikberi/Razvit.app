import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/exercise.dart';
import '../../../data/repositories/workout_repository.dart';
import 'widgets/exercise_media.dart';

/// Экран активной тренировки — раньше был сплошь тёмным (ink900) с GIF/видео
/// без кэша, летящим в широкий контейнер и обрезанным по бокам. Теперь: тот
/// же светлый, "Apple-style" визуальный язык, что и в остальном приложении
/// (белые карточки, мягкие тени, зелёный акцент), квадратная GIF-карточка
/// без искажений — см. exercise_media.dart.
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _syncDefaults(state);

    final day = state.day;
    final exercise = state.currentExercise;
    final progress = day.exercises.isEmpty ? 0.0 : (state.exerciseIndex) / day.exercises.length;

    // GIF занимает весь верх экрана (как просили) — панель с управлением
    // "плавает" поверх снизу закруглённой карточкой, как в Apple Fitness+,
    // а не отдельным прокручиваемым списком под маленькой картинкой.
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          Positioned.fill(child: ExerciseFullscreenMedia(exercise: exercise.exercise)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: Row(
                    children: [
                      // Обе боковые "гири" ровно 44×44 (минимальный tap-target Material) —
                      // раньше слева была скруглённая кнопка ~36px, а справа просто SizedBox
                      // шириной 40px, из-за чего заголовок в центре визуально съезжал в сторону.
                      SizedBox(width: 44, height: 44, child: _GlassButton(onTap: () => _confirmExit(context), icon: Icons.close_rounded)),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(day.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              '${state.exerciseIndex + 1} из ${day.exercises.length} упражнений',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Text(
                            _fmt(_elapsed),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 6, backgroundColor: AppColors.ink100),
                  ),
                ),
                const Spacer(),
                _BottomPanel(
                  name: exercise.exercise.name,
                  muscle: exercise.exercise.primaryMuscle.label,
                  actions: state.isResting
                      ? null
                      : Column(
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
                              child: const Text('Пропустить упражнение'),
                            ),
                          ],
                        ),
                  child: state.isResting
                      ? _RestPanel(seconds: state.restRemaining, total: exercise.restSeconds, onSkip: () => ref.read(activeWorkoutProvider.notifier).skipRest())
                      : _SetPanel(
                          setNumber: state.setIndex + 1,
                          totalSets: exercise.sets,
                          weight: _weight,
                          reps: _reps,
                          restLabel: exercise.restLabel,
                          onWeightChanged: (v) => setState(() => _weight = v),
                          onRepsChanged: (v) => setState(() => _reps = v),
                        ),
                ),
              ],
            ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Подход $setNumber из $totalSets', style: Theme.of(context).textTheme.titleMedium),
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
                  Text('Отдых', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.ink50, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Text(restLabel, style: Theme.of(context).textTheme.titleSmall),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _miniButton(Icons.remove_rounded, onDec),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
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
        decoration: const BoxDecoration(color: AppColors.ink100, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.ink900, size: 16),
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
    return Column(
      children: [
        Text('Отдых', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.ink500)),
        const SizedBox(height: AppSpacing.sm),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CircularProgressIndicator(value: progress, strokeWidth: 8, backgroundColor: AppColors.ink100, color: AppColors.green500),
            ),
            Text('$seconds', style: Theme.of(context).textTheme.headlineLarge),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: onSkip,
          child: const Text('Пропустить отдых'),
        ),
      ],
    );
  }
}

/// Полупрозрачная круглая кнопка поверх GIF (крестик закрытия) — читается
/// на любом фоне картинки, не сливается ни со светлыми, ни с тёмными
/// кадрами анимации.
class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.ink900, size: 20),
        ),
      ),
    );
  }
}

/// Панель управления, "плавающая" поверх полноэкранного GIF снизу —
/// закруглённые верхние углы, тень, вся логика подхода/отдыха и кнопки
/// живут здесь одним блоком, а не отдельными прокручиваемыми карточками.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.name, required this.muscle, required this.child, this.actions});

  final String name;
  final String muscle;
  final Widget child;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: AppShadows.raised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: Theme.of(context).textTheme.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(muscle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
          const SizedBox(height: AppSpacing.lg),
          child,
          if (actions != null) ...[
            const SizedBox(height: AppSpacing.lg),
            actions!,
          ],
        ],
      ),
    );
  }
}
