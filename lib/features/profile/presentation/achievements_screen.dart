import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/models/achievement.dart';
import '../../../data/repositories/workout_repository.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    final unlocked = achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Достижения'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.green50, AppColors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.card,
                border: Border.all(color: AppColors.green100),
              ),
              child: Row(
                children: [
                  ProgressRing(
                    progress: achievements.isEmpty ? 0 : unlocked / achievements.length,
                    size: 64,
                    strokeWidth: 6,
                    child: const Icon(Icons.emoji_events_rounded, color: AppColors.green600, size: 26),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$unlocked из ${achievements.length}', style: Theme.of(context).textTheme.headlineMedium),
                        Text('достижений открыто', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.95),
              itemCount: achievements.length,
              itemBuilder: (context, i) => _AchievementCard(achievement: achievements[i]),
            ),
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
    return AppCard(
      color: achievement.isUnlocked ? null : Theme.of(context).scaffoldBackgroundColor,
      shadow: achievement.isUnlocked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: achievement.isUnlocked ? 1 : 0.35,
            child: Text(achievement.emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            achievement.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: achievement.isUnlocked ? null : AppColors.ink400),
          ),
          const SizedBox(height: 2),
          Text(
            achievement.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!achievement.isUnlocked && achievement.progress != null && achievement.target != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(value: achievement.progress! / achievement.target!, minHeight: 5, backgroundColor: AppColors.ink200),
            ),
            const SizedBox(height: 4),
            Text('${achievement.progress}/${achievement.target}', style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}
