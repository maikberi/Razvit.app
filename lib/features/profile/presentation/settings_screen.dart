import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/repositories/user_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _workoutReminders = true;
  bool _waterReminders = true;
  bool _mealReminders = false;
  bool _trainerMessages = true;
  bool _achievements = true;
  bool _aiTips = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Уведомления', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _switchTile('Напоминание о тренировке', _workoutReminders, (v) => setState(() => _workoutReminders = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile('Напоминание о воде', _waterReminders, (v) => setState(() => _waterReminders = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile('Напоминание о питании', _mealReminders, (v) => setState(() => _mealReminders = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile('Сообщения от тренера', _trainerMessages, (v) => setState(() => _trainerMessages = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile('Достижения', _achievements, (v) => setState(() => _achievements = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile('AI-рекомендации', _aiTips, (v) => setState(() => _aiTips = v)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Аккаунт', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(title: const Text('Изменить пароль'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {}),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    title: const Text('Выйти', style: TextStyle(color: AppColors.error)),
                    trailing: const Icon(Icons.logout_rounded, color: AppColors.error),
                    onTap: () {
                      ref.read(authProvider.notifier).signOut();
                      context.go('/welcome');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(child: Text('RAZVIT · версия 1.0.0', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.green500,
    );
  }
}
