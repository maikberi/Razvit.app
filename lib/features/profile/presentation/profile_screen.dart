import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../data/mock/mock_achievements.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/user_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final unlockedAchievements = mockAchievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          children: [
            AppCard(
              child: Column(
                children: [
                  AppAvatar(name: user.name, size: 76),
                  const SizedBox(height: AppSpacing.sm),
                  Text('${user.name}${user.lastName != null ? ' ${user.lastName}' : ''}', style: Theme.of(context).textTheme.headlineMedium),
                  if (user.nickname != null)
                    Text(user.nickname!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                  Text(user.goal.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.green600, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: _stat(context, '${user.weightKg.toStringAsFixed(0)} кг', 'Вес')),
                      Expanded(child: _stat(context, '${user.heightCm} см', 'Рост')),
                      Expanded(child: _stat(context, '${user.streakDays}', 'Дней подряд')),
                      Expanded(child: _stat(context, '$unlockedAchievements', 'Награды')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionTile(icon: Icons.badge_outlined, title: 'Личные данные', subtitle: 'Имя, email, фото', onTap: () => _showPersonalData(context, user)),
            _SectionTile(icon: Icons.flag_outlined, title: 'Цели', subtitle: user.goal.label, onTap: () => _showGoal(context, user)),
            _SectionTile(icon: Icons.fitness_center_outlined, title: 'Мои программы', subtitle: 'Активные и завершённые', onTap: () => context.go('/workouts')),
            _SectionTile(icon: Icons.emoji_events_outlined, title: 'Достижения', subtitle: '$unlockedAchievements из ${mockAchievements.length} открыто', onTap: () => context.push('/achievements')),
            _SectionTile(icon: Icons.insights_outlined, title: 'Статистика', subtitle: 'Тренировки, объём, серии', onTap: () => context.push('/workout-stats')),
            _SectionTile(icon: Icons.settings_outlined, title: 'Настройки', subtitle: 'Уведомления, аккаунт', onTap: () => context.push('/settings')),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  void _showPersonalData(BuildContext context, AppUser user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Личные данные', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              _row(context, 'Имя', user.name),
              if (user.lastName != null) _row(context, 'Фамилия', user.lastName!),
              if (user.nickname != null) _row(context, 'Никнейм', user.nickname!),
              _row(context, 'Email', user.email),
              _row(context, 'Рост', '${user.heightCm} см'),
              _row(context, 'Вес', '${user.weightKg.toStringAsFixed(0)} кг'),
            ],
          ),
        ),
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

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
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
