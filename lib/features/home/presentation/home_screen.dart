import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mascot.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/mock/mock_progress.dart';
import '../../../data/models/workout_session.dart';
import '../../../data/repositories/nutrition_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/trainer_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/workout_repository.dart';

const _statBlue = Color(0xFF3B82F6);
const _statPurple = Color(0xFF8B5CF6);
const _weekdayLetters = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

String _weeksLabel(int weeks) {
  final mod100 = weeks % 100;
  final mod10 = weeks % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'недель';
  if (mod10 == 1) return 'неделю';
  if (mod10 >= 2 && mod10 <= 4) return 'недели';
  return 'недель';
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 6) return 'Доброй ночи';
  if (hour < 12) return 'Доброе утро';
  if (hour < 18) return 'Добрый день';
  return 'Добрый вечер';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final today = ref.watch(todayWorkoutProvider);
    final meals = ref.watch(mealsProvider);
    final plan = ref.watch(nutritionPlanProvider);
    final water = ref.watch(waterIntakeProvider);
    final trainer = ref.watch(myTrainerProvider);
    final weightHistory = ref.watch(weightHistoryProvider);
    final sessions = ref.watch(workoutSessionsProvider);

    final calories = meals.fold(0, (s, m) => s + m.calories);
    final protein = meals.fold(0.0, (s, m) => s + m.protein);
    final weightDelta = weightHistory.isEmpty ? 0.0 : user.weightKg - weightHistory.first.weightKg;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.headlineLarge,
                      children: [
                        TextSpan(text: '${_greeting()},\n'),
                        TextSpan(text: '${user.name}! 👋', style: const TextStyle(color: AppColors.green600)),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/nutrition-stats'),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: ProgressRing(
                      progress: plan.progressPercent / 100,
                      size: 64,
                      strokeWidth: 6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${plan.progressPercent}%', style: Theme.of(context).textTheme.titleSmall),
                          Text('Прогресс', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 8)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Ты на ${plan.progressPercent}% ближе к своей цели!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
            const SizedBox(height: AppSpacing.lg),
            _GoalCard(title: today.title, exercises: today.exercises.length, minutes: today.estimatedDuration.inMinutes, volumeKg: today.estimatedVolumeKg),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/workout-session'),
                style: OutlinedButton.styleFrom(backgroundColor: Theme.of(context).cardTheme.color, side: BorderSide.none, elevation: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Начать тренировку'),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Мои показатели', style: Theme.of(context).textTheme.titleLarge),
                _LinkText(label: 'Настроить', onTap: () => context.push('/settings')),
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
                    onTap: () => context.push('/nutrition-stats'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TodayStatCard(
                    icon: Icons.egg_alt_rounded,
                    color: _statBlue,
                    background: const Color(0xFFEAF1FE),
                    label: 'Белки',
                    value: protein.toStringAsFixed(0),
                    goal: '${plan.proteinGoal} г',
                    progress: plan.proteinGoal == 0 ? 0 : protein / plan.proteinGoal,
                    onTap: () => context.go('/nutrition'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TodayStatCard(
                    icon: Icons.water_drop_rounded,
                    color: AppColors.water,
                    background: const Color(0xFFE0FAFE),
                    label: 'Вода',
                    value: (water / 1000).toStringAsFixed(1),
                    goal: '${(plan.waterGoalMl / 1000).toStringAsFixed(1)} л',
                    progress: plan.waterGoalMl == 0 ? 0 : water / plan.waterGoalMl,
                    onTap: () => context.go('/nutrition'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TodayStatCard(
                    icon: Icons.monitor_weight_rounded,
                    color: _statPurple,
                    background: const Color(0xFFF2ECFE),
                    label: 'Вес',
                    value: user.weightKg.toStringAsFixed(0),
                    goal: 'кг',
                    trailing: Text(
                      '${weightDelta <= 0 ? '↓' : '↑'} ${weightDelta.abs().toStringAsFixed(1)} кг',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: weightDelta <= 0 ? AppColors.green600 : AppColors.error),
                    ),
                    onTap: () => context.push('/workout-stats'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Календарь тренировок', style: Theme.of(context).textTheme.titleLarge),
                _LinkText(label: 'Смотреть все', onTap: () => context.push('/workout-calendar')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _WeekCalendar(sessions: sessions),
            const SizedBox(height: AppSpacing.xl),
            _StreakCard(streakDays: user.streakDays),
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
  const _GoalCard({required this.title, required this.exercises, required this.minutes, required this.volumeKg});
  final String title;
  final int exercises;
  final int minutes;
  final double volumeKg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Сегодня по плану', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.green700)),
                const SizedBox(height: 4),
                Text('$title 💪', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.ink900)),
                const SizedBox(height: AppSpacing.sm),
                _bullet(context, Icons.format_list_bulleted_rounded, '$exercises упражнений'),
                const SizedBox(height: 4),
                _bullet(context, Icons.timer_outlined, '$minutes минут'),
                const SizedBox(height: 4),
                _bullet(context, Icons.bar_chart_rounded, '${volumeKg.round()} кг объём'),
              ],
            ),
          ),
          SizedBox(
            width: 150,
            height: 100,
            child: Image.asset(
              'assets/home/hero_dumbbells.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.green700),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink700)),
      ],
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
    this.progress,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final String value;
  final String goal;
  final double? progress;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
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
          trailing ??
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(value: (progress ?? 0).clamp(0, 1), minHeight: 5, backgroundColor: AppColors.ink100, color: color),
              ),
        ],
      ),
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({required this.sessions});
  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++) _dayColumn(context, startOfWeek.add(Duration(days: i)), today),
        ],
      ),
    );
  }

  Widget _dayColumn(BuildContext context, DateTime date, DateTime today) {
    final isToday = date == today;
    WorkoutSession? session;
    for (final s in sessions) {
      final sDate = DateTime(s.date.year, s.date.month, s.date.day);
      if (sDate == date) {
        session = s;
        break;
      }
    }

    Color bg;
    Color fg;
    Widget? child;
    if (session?.status == SessionStatus.done) {
      bg = AppColors.green500;
      fg = Colors.white;
      child = const Icon(Icons.check_rounded, size: 16, color: Colors.white);
    } else if (session?.status == SessionStatus.missed) {
      bg = Theme.of(context).dividerColor;
      fg = AppColors.ink500;
      child = Text('${date.day}', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700));
    } else {
      bg = Colors.transparent;
      fg = AppColors.ink400;
      child = Text('${date.day}', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700));
    }

    return Column(
      children: [
        Text(_weekdayLetters[date.weekday - 1], style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: isToday ? Border.all(color: AppColors.green600, width: 2) : Border.all(color: Theme.of(context).dividerColor),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streakDays});
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.isDarkMode ? AppColors.green500.withValues(alpha: 0.16) : AppColors.green50,
      shadow: false,
      onTap: () => context.push('/ai-assistant'),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$streakDays дней подряд', style: Theme.of(context).textTheme.titleSmall),
                Text('Не останавливайся!', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const RazvitMascot(size: 44),
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
    final weeks = history.isEmpty ? 0 : (DateTime.now().difference(history.first.date).inDays / 7).round();
    final steps = 4;
    final labels = List.generate(steps, (i) => (maxW - (maxW - minW) * i / (steps - 1)).round());

    return AppCard(
      onTap: () => context.push('/workout-stats'),
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
                  '${delta <= 0 ? '' : '+'}${delta.toStringAsFixed(1)} кг за $weeks ${_weeksLabel(weeks)}',
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
