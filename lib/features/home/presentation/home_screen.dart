import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../data/mock/mock_progress.dart';
import '../../../data/repositories/nutrition_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/trainer_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/workout_repository.dart';

const _statBlue = Color(0xFF3B82F6);
const _statPurple = Color(0xFF8B5CF6);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final today = ref.watch(todayWorkoutProvider);
    final meals = ref.watch(mealsProvider);
    final plan = ref.watch(nutritionPlanProvider);
    final trainer = ref.watch(myTrainerProvider);
    final weightHistory = ref.watch(weightHistoryProvider);

    final calories = meals.fold(0, (s, m) => s + m.calories);
    final mealsDone = meals.where((m) => m.entries.isNotEmpty).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RAZVIT',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 0.5),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.push('/notifications'),
                      icon: const Icon(Icons.notifications_none_rounded),
                      style: IconButton.styleFrom(backgroundColor: AppColors.white, shape: const CircleBorder()),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.go('/profile'),
                      child: AppAvatar(name: user.name, size: 40),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Привет, ${user.name}! 👋', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text('Готов к новой лучшей версии себя?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
            const SizedBox(height: AppSpacing.lg),
            _GoalCard(subtitle: today.title, streakDays: user.streakDays),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Сегодня', style: Theme.of(context).textTheme.titleLarge),
                _LinkText(label: 'Смотреть все', onTap: () => context.push('/workout-stats')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _TodayStatCard(
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.green600,
                    background: AppColors.green50,
                    label: 'Калории',
                    value: '$calories',
                    goal: '${plan.calorieGoal} ккал',
                    progress: plan.calorieGoal == 0 ? 0 : calories / plan.calorieGoal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TodayStatCard(
                    icon: Icons.fitness_center_rounded,
                    color: _statBlue,
                    background: const Color(0xFFEAF1FE),
                    label: 'Тренировка',
                    value: '0',
                    goal: '${today.estimatedDuration.inMinutes} мин',
                    progress: 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TodayStatCard(
                    icon: Icons.restaurant_rounded,
                    color: _statPurple,
                    background: const Color(0xFFF2ECFE),
                    label: 'Питание',
                    value: '$mealsDone',
                    goal: '${meals.length} приёмов',
                    progress: meals.isEmpty ? 0 : mealsDone / meals.length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Прогресс', style: Theme.of(context).textTheme.titleLarge),
                _LinkText(label: 'Подробнее', onTap: () => context.push('/workout-stats')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _ProgressCard(history: weightHistory, currentWeight: user.weightKg),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Тренировки', style: Theme.of(context).textTheme.titleLarge),
                _LinkText(label: 'Смотреть все', onTap: () => context.push('/workouts')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _WorkoutRow(
              icon: Icons.fitness_center_rounded,
              color: _statBlue,
              background: const Color(0xFFEAF1FE),
              title: today.title,
              subtitle: '${today.estimatedDuration.inMinutes} мин • ${today.exercises.length} упражнений',
              tag: 'Силовая тренировка',
              onTap: () => context.push('/workout-session'),
            ),
            const SizedBox(height: 10),
            _WorkoutRow(
              icon: Icons.directions_run_rounded,
              color: _statPurple,
              background: const Color(0xFFF2ECFE),
              title: 'Кардио',
              subtitle: '30 мин • Средняя интенсивность',
              tag: 'Беговая дорожка',
              onTap: () => context.push('/workouts'),
            ),
            const SizedBox(height: AppSpacing.xl),
            _AiMentorCard(),
            const SizedBox(height: AppSpacing.sm),
            _TrainerCard(name: trainer.name, isOnline: trainer.isOnline, rating: trainer.rating, seed: trainer.avatarSeed, id: trainer.id),
          ],
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.green600)),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.subtitle, required this.streakDays});
  final String subtitle;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('Твоя цель на сегодня', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.green700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text('$streakDays дней подряд', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Тренировка', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () => context.push('/workout-session'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 22)),
                      child: const Text('Начать тренировку'),
                    ),
                  ],
                ),
              ),
              Container(
                width: 88,
                height: 88,
                margin: const EdgeInsets.only(left: AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.greenGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayStatCard extends StatelessWidget {
  const _TodayStatCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
    required this.value,
    required this.goal,
    required this.progress,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final String value;
  final String goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text('/ $goal', style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(value: progress.clamp(0, 1), minHeight: 5, backgroundColor: AppColors.ink100, color: color),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.history, required this.currentWeight});
  final List<WeightEntry> history;
  final double currentWeight;

  @override
  Widget build(BuildContext context) {
    final weights = history.map((e) => e.weightKg).toList();
    final minW = (weights.reduce((a, b) => a < b ? a : b) - 1).floorToDouble();
    final maxW = (weights.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble();
    final delta = history.isEmpty ? 0.0 : currentWeight - history.first.weightKg;
    final steps = 4;
    final labels = List.generate(steps, (i) => (maxW - (maxW - minW) * i / (steps - 1)).round());

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Вес', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('${currentWeight.toStringAsFixed(1)} кг', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  '${delta <= 0 ? '' : '+'}${delta.toStringAsFixed(1)} кг за 3 недели',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: delta <= 0 ? AppColors.green600 : AppColors.error),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 26,
            height: 110,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (final l in labels) Text('$l', style: Theme.of(context).textTheme.labelSmall)],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 110,
              child: LineChart(
                LineChartData(
                  minY: minW,
                  maxY: maxW,
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < weights.length; i++) FlSpot(i.toDouble(), weights[i])],
                      isCurved: true,
                      color: AppColors.green500,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                Text(tag, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink400)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(Icons.play_arrow_rounded, color: color),
            ),
          ),
        ],
      ),
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
