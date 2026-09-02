import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../data/repositories/nutrition_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/trainer_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../widgets/week_strip.dart';
import '../widgets/weight_chart_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Доброй ночи';
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final today = ref.watch(todayWorkoutProvider);
    final meals = ref.watch(mealsProvider);
    final plan = ref.watch(nutritionPlanProvider);
    final water = ref.watch(waterIntakeProvider);
    final sessions = ref.watch(workoutSessionsProvider);
    final trainer = ref.watch(myTrainerProvider);
    final weightHistory = ref.watch(weightHistoryProvider);

    final calories = meals.fold(0, (s, m) => s + m.calories);
    final protein = meals.fold(0.0, (s, m) => s + m.protein);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: '${_greeting()}, ',
                          style: Theme.of(context).textTheme.headlineMedium,
                          children: [
                            TextSpan(text: '${user.name}! 👋', style: const TextStyle(color: AppColors.green600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Ты на шаг ближе к своей цели', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: const Icon(Icons.notifications_none_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.white, shape: const CircleBorder()),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _TodayWorkoutCard(title: today.title, exercises: today.exercises.length, minutes: today.estimatedDuration.inMinutes, volume: today.estimatedVolumeKg),
            const SizedBox(height: AppSpacing.lg),
            Text('Мои показатели', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Калории', value: '$calories', unit: '/ ${plan.calorieGoal} ккал', icon: Icons.local_fire_department_rounded)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: StatTile(label: 'Белки', value: protein.toStringAsFixed(0), unit: '/ ${plan.proteinGoal} г', icon: Icons.egg_alt_outlined)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Вода',
                    value: (water / 1000).toStringAsFixed(1),
                    unit: '/ ${(plan.waterGoalMl / 1000).toStringAsFixed(1)} л',
                    icon: Icons.water_drop_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(
                    label: 'Вес',
                    value: user.weightKg.toStringAsFixed(0),
                    unit: 'кг',
                    trend: '${(user.weightKg - user.startWeightKg).toStringAsFixed(1)} кг',
                    trendUp: user.weightKg <= user.startWeightKg,
                    icon: Icons.monitor_weight_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            WeekStripCard(sessions: sessions, streakDays: user.streakDays),
            const SizedBox(height: AppSpacing.lg),
            _AiMentorCard(),
            const SizedBox(height: AppSpacing.lg),
            _TrainerCard(name: trainer.name, isOnline: trainer.isOnline, rating: trainer.rating, seed: trainer.avatarSeed, id: trainer.id),
            const SizedBox(height: AppSpacing.lg),
            WeightChartCard(history: weightHistory, currentWeight: user.weightKg),
          ],
        ),
      ),
    );
  }
}

class _TodayWorkoutCard extends StatelessWidget {
  const _TodayWorkoutCard({required this.title, required this.exercises, required this.minutes, required this.volume});
  final String title;
  final int exercises;
  final int minutes;
  final double volume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.greenGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.button,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сегодня по плану', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _pill(context, Icons.fitness_center_rounded, '$exercises упражнений'),
              const SizedBox(width: 8),
              _pill(context, Icons.timer_outlined, '$minutes минут'),
            ],
          ),
          const SizedBox(height: 6),
          _pill(context, Icons.bar_chart_rounded, '${volume.round()} кг объём'),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.push('/workout-session');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.green700),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Начать тренировку'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
      ],
    );
  }
}

class _AiMentorCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.green50,
      shadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.green500, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI-наставник', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Ты отлично держишь темп. На следующей тренировке можно немного увеличить нагрузку.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text('Посмотреть рекомендации', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.green700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({required this.name, required this.isOnline, required this.rating, required this.seed, required this.id});
  final String name;
  final bool isOnline;
  final double rating;
  final int seed;
  final String id;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/trainer/$id'),
      child: Row(
        children: [
          Stack(
            children: [
              AppAvatar(name: name, seed: seed, size: 48),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: AppColors.green500, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                Text('Персональный тренер · ★ $rating', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/chat/$id'),
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.green600),
          ),
        ],
      ),
    );
  }
}
