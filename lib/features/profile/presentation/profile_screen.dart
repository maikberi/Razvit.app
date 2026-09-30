import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mascot.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import 'profile_edit_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final achievements = ref.watch(achievementsProvider);
    final unlockedAchievements = achievements.where((a) => a.isUnlocked).length;
    final streakDays = ref.watch(workoutStreakProvider);
    final weightHistory = ref.watch(weightHistoryProvider).valueOrNull ?? const [];
    final currentWeight = weightHistory.isEmpty ? user.weightKg : weightHistory.last.weightKg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          children: [
            AppCard(
              onTap: () => showProfileEditSheet(context),
              child: Row(
                children: [
                  AppAvatar(name: user.name, size: 60, imageUrl: user.avatarUrl),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user.name}${user.lastName != null ? ' ${user.lastName}' : ''}', style: Theme.of(context).textTheme.titleLarge),
                        if (user.nickname != null)
                          Text('@${user.nickname}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
                        const SizedBox(height: 6),
                        _GoalTag(icon: Icons.track_changes_rounded, label: user.goal.label),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, color: AppColors.ink300),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Моя текущая серия', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _StreakCard(streakDays: streakDays),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: _statCard(context, '${currentWeight.toStringAsFixed(0)} кг', 'Вес', onTap: () => context.push('/workout-stats'))),
                const SizedBox(width: 10),
                Expanded(child: _statCard(context, '${user.heightCm} см', 'Рост', onTap: () => showProfileEditSheet(context))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _statCard(context, '$streakDays', 'Дней подряд', onTap: () => context.push('/workout-calendar'))),
                const SizedBox(width: 10),
                Expanded(child: _statCard(context, '$unlockedAchievements', 'Награды', onTap: () => context.push('/achievements'))),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionTile(icon: Icons.badge_outlined, title: 'Личные данные', subtitle: 'Имя, фамилия, никнейм, фото', onTap: () => showProfileEditSheet(context)),
            _SectionTile(icon: Icons.flag_outlined, title: 'Цели', subtitle: user.goal.label, onTap: () => _showGoal(context, user)),
            _SectionTile(icon: Icons.fitness_center_outlined, title: 'Мои программы', subtitle: 'Активные и завершённые', onTap: () => context.go('/workouts')),
            _SectionTile(icon: Icons.emoji_events_outlined, title: 'Достижения', subtitle: '$unlockedAchievements из ${achievements.length} открыто', onTap: () => context.push('/achievements')),
            _SectionTile(icon: Icons.insights_outlined, title: 'Статистика', subtitle: 'Тренировки, объём, серии', onTap: () => context.push('/workout-stats')),
            _SectionTile(icon: Icons.groups_outlined, title: 'Тренерская программа', subtitle: 'Мой тренер и мои клиенты', onTap: () => context.push('/coaching')),
            _SectionTile(icon: Icons.settings_outlined, title: 'Настройки', subtitle: 'Уведомления, аккаунт', onTap: () => context.push('/settings')),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, String value, String label, {VoidCallback? onTap}) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  void _showGoal(BuildContext context, AppUser user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Твоя цель', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(user.goal.label, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.green600)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Было: ${user.startWeightKg.toStringAsFixed(0)} кг → Стало: ${user.weightKg.toStringAsFixed(0)} кг',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(icon, color: AppColors.green600, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
          ],
        ),
      ),
    );
  }
}

class _GoalTag extends StatelessWidget {
  const _GoalTag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.green600),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green700)),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streakDays});
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final active = streakDays > 0;
    return AppCard(
      color: context.isDarkMode ? AppColors.green500.withValues(alpha: 0.16) : AppColors.green50,
      shadow: false,
      child: Row(
        children: [
          const RazvitMascot(size: 64),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? '$streakDays дней подряд' : 'Начни серию',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  active ? 'Не останавливайся — так держать!' : 'Добавляй тренировку или приём пищи каждый день',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
