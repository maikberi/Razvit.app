import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
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
            AppCard(
              color: AppColors.green500,
              shadow: false,
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$unlocked из ${achievements.length}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const Text('достижений открыто', style: TextStyle(color: Colors.white70)),
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
