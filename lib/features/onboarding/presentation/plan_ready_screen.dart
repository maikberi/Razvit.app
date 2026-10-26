import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_emoji.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/models/workout.dart';
import '../../../data/repositories/user_repository.dart';

/// Результат настоящей генерации плана (см. plan_generating_screen.dart) —
/// реальные, уже сохранённые на backend цели по питанию и программа
/// тренировок, а не локально посчитанная демонстрационная заглушка
/// (как было раньше в core/utils/plan_calculator.dart).
class GeneratedPlan {
  const GeneratedPlan({required this.nutrition, required this.program});
  final NutritionPlan nutrition;
  final WorkoutProgram program;
}

class PlanReadyScreen extends ConsumerWidget {
  const PlanReadyScreen({super.key, required this.plan});

  final GeneratedPlan? plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = this.plan;
    if (plan == null) {
      // Экран открыт напрямую, без прохождения генерации (например,
      // случайный переход назад/вперёд в браузере) — самого плана в
      // памяти нет, показывать нечего. Отправляем на Главную вместо
      // пустого/сломанного экрана.
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Данные плана недоступны', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(onPressed: () => context.go('/home'), child: const Text('На главную')),
              ],
            ),
          ),
        ),
      );
    }

    final program = plan.program;
    final nutrition = plan.nutrition;
    final firstDayVolume = program.days.isEmpty
        ? 0
        : program.days
            .map((d) => d.estimatedVolumeKg)
            .reduce((a, b) => a + b) ~/
            program.days.length;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                            left: 40,
                            top: 4,
                            child: AnimatedEmoji('✨', fontSize: 18)),
                        const Positioned(
                            right: 36,
                            top: 10,
                            child: AnimatedEmoji('✨', fontSize: 14)),
                        const AnimatedEmoji('🔥', fontSize: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideIn(
                      child: Text('Твой план готов!',
                          style: Theme.of(context).textTheme.headlineLarge)),
                  const SizedBox(height: 6),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      program.goal.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.green600,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 160),
                            child: AppCard(
                              child: Column(
                                children: [
                                  _row(
                                      context,
                                      Icons.fitness_center_rounded,
                                      'Тренировок в неделю',
                                      '${program.trainingDays.length}'),
                                  const Divider(height: AppSpacing.lg),
                                  _row(context, Icons.calendar_month_rounded,
                                      'Программа', '${program.days.length} дней · ${program.totalWeeks} нед'),
                                  const Divider(height: AppSpacing.lg),
                                  _row(
                                      context,
                                      Icons.local_fire_department_rounded,
                                      'Калорийность',
                                      '${nutrition.calorieGoal} ккал'),
                                  const Divider(height: AppSpacing.lg),
                                  _row(
                                      context,
                                      Icons.water_drop_rounded,
                                      'Вода',
                                      '${(nutrition.waterGoalMl / 1000).toStringAsFixed(1)} л'),
                                  if (firstDayVolume > 0) ...[
                                    const Divider(height: AppSpacing.lg),
                                    _row(context, Icons.bar_chart_rounded, 'Объём за тренировку', '~$firstDayVolume кг'),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 240),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('БЖУ на день',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    children: [
                                      _macro(context, 'Белки', nutrition.proteinGoal,
                                          AppColors.protein),
                                      _macro(context, 'Жиры', nutrition.fatGoal,
                                          AppColors.fat),
                                      _macro(context, 'Углеводы', nutrition.carbsGoal,
                                          AppColors.carbs),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (program.days.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 300),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Дни программы', style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: AppSpacing.sm),
                                    for (final day in program.days)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.circle, size: 6, color: AppColors.green500),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(day.title, style: Theme.of(context).textTheme.bodyMedium)),
                                            Text('${day.exercises.length} упр.', style: Theme.of(context).textTheme.bodySmall),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 320),
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(onboardingCompletedProvider.notifier)
                            .complete();
                        context.go('/home');
                      },
                      child: const Text('Начать путь'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.green600, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }

  Widget _macro(BuildContext context, String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(height: 6),
          Text('$value г', style: Theme.of(context).textTheme.titleSmall),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
