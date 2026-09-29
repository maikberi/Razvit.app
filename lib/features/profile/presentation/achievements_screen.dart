import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/models/achievement.dart';
import '../../../data/repositories/workout_repository.dart';

/// Цвет-акцент под конкретное достижение — раньше все карточки были
/// одинаково зелёными (только эмодзи отличались), из-за чего экран
/// выглядел плоско. Один и тот же набор цветов, что уже используется по
/// всему приложению для смысловых категорий (огонь/трофей/рекорд и т.д.).
(Color, Color) _accentFor(String id) => switch (id) {
      'first_workout' => (AppColors.green600, AppColors.green50),
      'streak_7' => (const Color(0xFFEF4444), const Color(0xFFFEE9E9)),
      'streak_30' => (const Color(0xFFF59E0B), const Color(0xFFFFF4DF)),
      'new_pr' => (const Color(0xFF8B5CF6), const Color(0xFFF2ECFE)),
      'workouts_100' => (const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      'volume_10000' => (const Color(0xFF06B6D4), const Color(0xFFE0FAFE)),
      _ => (AppColors.green600, AppColors.green50),
    };

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    final unlocked = achievements.where((a) => a.isUnlocked).length;
    final progress = achievements.isEmpty ? 0.0 : unlocked / achievements.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Достижения'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Крупная тёмная шапка вместо бледной зелёной карточки — тот же
            // язык, что и в hero-карточке Главной: заметный акцент, вместо
            // очередной белой карточки среди других белых карточек.
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.darkSurface, AppColors.darkSurfaceElevated],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => ProgressRing(
                      progress: value,
                      size: 84,
                      strokeWidth: 8,
                      color: AppColors.green400,
                      trackColor: Colors.white.withValues(alpha: 0.12),
                      child: child,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: AppColors.green400, size: 32),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$unlocked из ${achievements.length}',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'достижений открыто',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final a in achievements) ...[
              _AchievementCard(achievement: a),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});
  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final (accent, accentBg) = _accentFor(achievement.id);
    final unlocked = achievement.isUnlocked;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: unlocked
            ? LinearGradient(colors: [accentBg, AppColors.white], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: unlocked ? null : AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: unlocked ? AppShadows.card : null,
        border: unlocked ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: unlocked ? accent.withValues(alpha: 0.16) : AppColors.ink100,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Opacity(
              opacity: unlocked ? 1 : 0.4,
              child: Text(achievement.emoji, style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: unlocked ? null : AppColors.ink400),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500),
                ),
                if (!unlocked && achievement.progress != null && achievement.target != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: achievement.progress! / achievement.target!,
                      minHeight: 6,
                      backgroundColor: AppColors.ink100,
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${achievement.progress} из ${achievement.target}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (unlocked)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
            )
          else
            const Icon(Icons.lock_outline_rounded, color: AppColors.ink300, size: 22),
        ],
      ),
    );
  }
}
