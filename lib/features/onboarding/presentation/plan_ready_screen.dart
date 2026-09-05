import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/plan_calculator.dart';
import '../../../core/widgets/animated_emoji.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/onboarding_repository.dart';
import '../../../data/repositories/user_repository.dart';

class PlanReadyScreen extends ConsumerWidget {
  const PlanReadyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);
    final plan = calculatePlan(profile);

    return Scaffold(
      body: SafeArea(
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
                    const Positioned(left: 40, top: 4, child: AnimatedEmoji('✨', fontSize: 18)),
                    const Positioned(right: 36, top: 10, child: AnimatedEmoji('✨', fontSize: 14)),
                    const AnimatedEmoji('🔥', fontSize: 48),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FadeSlideIn(child: Text('Твой план готов!', style: Theme.of(context).textTheme.headlineLarge)),
              const SizedBox(height: 6),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Text(
                  profile.goal?.label ?? 'Персональная программа',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.green600, fontWeight: FontWeight.w700),
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
                              _row(context, Icons.fitness_center_rounded, 'Тренировок в неделю', '${plan.workoutsPerWeek}'),
                              const Divider(height: AppSpacing.lg),
                              _row(context, Icons.timer_outlined, 'Продолжительность', plan.durationLabel),
                              const Divider(height: AppSpacing.lg),
                              _row(context, Icons.local_fire_department_rounded, 'Калорийность', '${plan.calories} ккал'),
                              const Divider(height: AppSpacing.lg),
                              _row(context, Icons.water_drop_rounded, 'Вода', '${(plan.waterMl / 1000).toStringAsFixed(1)} л'),
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
                              Text('БЖУ на день', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  _macro(context, 'Белки', plan.protein, AppColors.protein),
                                  _macro(context, 'Жиры', plan.fat, AppColors.fat),
                                  _macro(context, 'Углеводы', plan.carbs, AppColors.carbs),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 320),
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(onboardingCompletedProvider.notifier).complete();
                    context.go('/home');
                  },
                  child: const Text('Начать путь'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.green600, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }

  Widget _macro(BuildContext context, String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(height: 6),
          Text('$value г', style: Theme.of(context).textTheme.titleSmall),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
