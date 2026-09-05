import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/exercise.dart';
import '../../../data/models/workout.dart';
import '../../../data/repositories/workout_repository.dart';

class _DraftExercise {
  _DraftExercise({required this.exercise});
  final Exercise exercise;
  int sets = 3;
  String repsLabel = '8–12';
  double weightKg = 20;
  int restSeconds = 60;
}

const _weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

class CreateProgramScreen extends ConsumerStatefulWidget {
  const CreateProgramScreen({super.key});

  @override
  ConsumerState<CreateProgramScreen> createState() => _CreateProgramScreenState();
}

class _CreateProgramScreenState extends ConsumerState<CreateProgramScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const _totalSteps = 4;

  final _titleController = TextEditingController(text: 'Моя программа');
  ProgramGoal _goal = ProgramGoal.mass;
  ProgramLevel _level = ProgramLevel.intermediate;
  final Set<int> _days = {1, 3, 5};
  int _durationMinutes = 60;
  bool _reminder = true;
  int _reminderBefore = 30;
  final List<_DraftExercise> _exercises = [];

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _titleController.text.trim().isNotEmpty;
      case 1:
        return _days.isNotEmpty;
      case 2:
        return _exercises.isNotEmpty;
      default:
        return true;
    }
  }

  void _next() {
    if (_step == _totalSteps - 1) {
      _save();
      return;
    }
    setState(() => _step++);
    _pageController.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _save() {
    final program = WorkoutProgram(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      goal: _goal,
      level: _level,
      totalWeeks: 8,
      currentWeek: 1,
      trainingDays: _days.toList()..sort(),
      isCustom: true,
      imageSeed: 3,
      days: [
        WorkoutDay(
          id: 'day_1',
          title: _titleController.text.trim(),
          exercises: [
            for (final d in _exercises)
              ProgramExercise(exercise: d.exercise, sets: d.sets, repsLabel: d.repsLabel, weightKg: d.weightKg, restSeconds: d.restSeconds),
          ],
        ),
      ],
    );
    ref.read(customProgramsProvider.notifier).add(program);
    context.go('/workouts');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Column(
          children: [
            Text('Создание программы', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _totalSteps; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 28,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _step ? AppColors.green500 : AppColors.ink200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepBasics(titleController: _titleController, goal: _goal, level: _level, onGoal: (g) => setState(() => _goal = g), onLevel: (l) => setState(() => _level = l)),
                  _StepSchedule(
                    days: _days,
                    durationMinutes: _durationMinutes,
                    reminder: _reminder,
                    reminderBefore: _reminderBefore,
                    onToggleDay: (d) => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d)),
                    onDuration: (v) => setState(() => _durationMinutes = v),
                    onReminder: (v) => setState(() => _reminder = v),
                    onReminderBefore: (v) => setState(() => _reminderBefore = v),
                  ),
                  _StepExercises(exercises: _exercises, onChanged: () => setState(() {})),
                  _StepReview(
                    title: _titleController.text,
                    goal: _goal,
                    level: _level,
                    days: _days,
                    exercises: _exercises,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
              child: ElevatedButton(
                onPressed: _canContinue ? _next : null,
                child: Text(_step == _totalSteps - 1 ? 'Сохранить программу' : 'Далее'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBasics extends StatelessWidget {
  const _StepBasics({required this.titleController, required this.goal, required this.level, required this.onGoal, required this.onLevel});
  final TextEditingController titleController;
  final ProgramGoal goal;
  final ProgramLevel level;
  final ValueChanged<ProgramGoal> onGoal;
  final ValueChanged<ProgramLevel> onLevel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1. Название программы', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: titleController, maxLength: 30, decoration: const InputDecoration(hintText: 'Моя идеальная программа')),
          const SizedBox(height: AppSpacing.md),
          Text('2. Цель программы', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final g in ProgramGoal.values) SelectableOptionCard(label: g.label, selected: goal == g, onTap: () => onGoal(g)),
          const SizedBox(height: AppSpacing.md),
          Text('3. Уровень подготовки', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final l in ProgramLevel.values) SelectableOptionCard(label: l.label, selected: level == l, onTap: () => onLevel(l)),
        ],
      ),
    );
  }
}

class _StepSchedule extends StatelessWidget {
  const _StepSchedule({
    required this.days,
    required this.durationMinutes,
    required this.reminder,
    required this.reminderBefore,
    required this.onToggleDay,
    required this.onDuration,
    required this.onReminder,
    required this.onReminderBefore,
  });

  final Set<int> days;
  final int durationMinutes;
  final bool reminder;
  final int reminderBefore;
  final ValueChanged<int> onToggleDay;
  final ValueChanged<int> onDuration;
  final ValueChanged<bool> onReminder;
  final ValueChanged<int> onReminderBefore;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Дни и расписание', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          Text('Выбери дни тренировок', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 1; i <= 7; i++)
                SelectableChip(label: _weekdayLabels[i - 1], selected: days.contains(i), onTap: () => onToggleDay(i)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Длительность тренировки', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filled(
                  onPressed: () => onDuration((durationMinutes - 5).clamp(15, 180)),
                  icon: const Icon(Icons.remove_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
                ),
                Text('$durationMinutes мин', style: Theme.of(context).textTheme.titleLarge),
                IconButton.filled(
                  onPressed: () => onDuration((durationMinutes + 5).clamp(15, 180)),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Напоминание', style: Theme.of(context).textTheme.titleSmall),
                      Text(reminder ? 'За $reminderBefore минут' : 'Отключено', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(value: reminder, onChanged: onReminder, activeColor: AppColors.green500),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepExercises extends ConsumerWidget {
  const _StepExercises({required this.exercises, required this.onChanged});
  final List<_DraftExercise> exercises;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: exercises.isEmpty
              ? EmptyState(
                  emoji: '➕',
                  title: 'Добавь упражнения',
                  subtitle: 'Собери тренировочный день из библиотеки RAZVIT',
                  actionLabel: 'Добавить упражнение',
                  onAction: () => _pickExercise(context, ref),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: exercises.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final item = exercises.removeAt(oldIndex);
                    exercises.insert(newIndex, item);
                    onChanged();
                  },
                  itemBuilder: (context, i) => Padding(
                    key: ValueKey(exercises[i].hashCode ^ i),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DraftExerciseCard(
                      draft: exercises[i],
                      onChanged: onChanged,
                      onRemove: () {
                        exercises.removeAt(i);
                        onChanged();
                      },
                    ),
                  ),
                ),
        ),
        if (exercises.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: OutlinedButton.icon(
              onPressed: () => _pickExercise(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить упражнение'),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  void _pickExercise(BuildContext context, WidgetRef ref) {
    final all = ref.read(exerciseCatalogProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: all.length,
          itemBuilder: (context, i) {
            final e = all[i];
            return ListTile(
              title: Text(e.name),
              subtitle: Text(e.primaryMuscle.label),
              onTap: () {
                exercises.add(_DraftExercise(exercise: e));
                onChanged();
                Navigator.of(context).pop();
              },
            );
          },
        ),
      ),
    );
  }
}

class _DraftExerciseCard extends StatelessWidget {
  const _DraftExerciseCard({required this.draft, required this.onChanged, required this.onRemove});
  final _DraftExercise draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.drag_indicator_rounded, color: AppColors.ink300),
              const SizedBox(width: 6),
              Expanded(child: Text(draft.exercise.name, style: Theme.of(context).textTheme.titleSmall)),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _miniStepper(context, 'Подходы', '${draft.sets}', () {
                draft.sets = (draft.sets + 1).clamp(1, 10);
                onChanged();
              }, () {
                draft.sets = (draft.sets - 1).clamp(1, 10);
                onChanged();
              })),
              const SizedBox(width: 8),
              Expanded(child: _miniStepper(context, 'Вес (кг)', draft.weightKg.toStringAsFixed(0), () {
                draft.weightKg = (draft.weightKg + 2.5).clamp(0, 400);
                onChanged();
              }, () {
                draft.weightKg = (draft.weightKg - 2.5).clamp(0, 400);
                onChanged();
              })),
              const SizedBox(width: 8),
              Expanded(child: _miniStepper(context, 'Отдых (с)', '${draft.restSeconds}', () {
                draft.restSeconds = (draft.restSeconds + 15).clamp(15, 240);
                onChanged();
              }, () {
                draft.restSeconds = (draft.restSeconds - 15).clamp(15, 240);
                onChanged();
              })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStepper(BuildContext context, String label, String value, VoidCallback onInc, VoidCallback onDec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Row(
          children: [
            GestureDetector(onTap: onDec, child: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppColors.ink500)),
            Expanded(child: Center(child: Text(value, style: Theme.of(context).textTheme.titleSmall))),
            GestureDetector(onTap: onInc, child: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.green600)),
          ],
        ),
      ],
    );
  }
}

class _StepReview extends StatelessWidget {
  const _StepReview({required this.title, required this.goal, required this.level, required this.days, required this.exercises});
  final String title;
  final ProgramGoal goal;
  final ProgramLevel level;
  final Set<int> days;
  final List<_DraftExercise> exercises;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Проверь программу', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('${goal.label} · ${level.label}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                const SizedBox(height: 8),
                Text(
                  (days.toList()..sort()).map((d) => _weekdayLabels[d - 1]).join(', '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Упражнения (${exercises.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final e in exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(e.exercise.name, style: Theme.of(context).textTheme.bodyMedium)),
                    Text('${e.sets} × ${e.repsLabel}', style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
