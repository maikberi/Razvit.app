import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/repositories/health_repository.dart';
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
    final themeMode = ref.watch(themeModeProvider);
    final healthConnected = ref.watch(healthConnectedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Тема', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: SelectableChip(
                    label: 'Светлая',
                    selected: themeMode == ThemeMode.light,
                    onTap: () => ref.read(themeModeProvider.notifier).setMode(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableChip(
                    label: 'Тёмная',
                    selected: themeMode == ThemeMode.dark,
                    onTap: () => ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableChip(
                    label: 'Как в системе',
                    selected: themeMode == ThemeMode.system,
                    onTap: () => ref.read(themeModeProvider.notifier).setMode(ThemeMode.system),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Здоровье', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                secondary: _tonalIcon(Icons.monitor_heart_rounded),
                title: const Text('Подключить Google Fit / Apple Health'),
                subtitle: const Text('Учёт шагов в приложении'),
                value: healthConnected,
                onChanged: (v) => ref.read(healthConnectedProvider.notifier).setConnected(v),
                activeColor: AppColors.green500,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Уведомления', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _switchTile(Icons.fitness_center_rounded, 'Напоминание о тренировке', _workoutReminders, (v) => setState(() => _workoutReminders = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile(Icons.water_drop_rounded, 'Напоминание о воде', _waterReminders, (v) => setState(() => _waterReminders = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile(Icons.restaurant_rounded, 'Напоминание о питании', _mealReminders, (v) => setState(() => _mealReminders = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile(Icons.chat_bubble_rounded, 'Сообщения от тренера', _trainerMessages, (v) => setState(() => _trainerMessages = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile(Icons.emoji_events_rounded, 'Достижения', _achievements, (v) => setState(() => _achievements = v)),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _switchTile(Icons.auto_awesome_rounded, 'AI-рекомендации', _aiTips, (v) => setState(() => _aiTips = v)),
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
                  ListTile(
                    leading: _tonalIcon(Icons.lock_outline_rounded),
                    title: const Text('Изменить пароль'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
                    onTap: () => _showChangePassword(context),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: _tonalIcon(Icons.logout_rounded, color: AppColors.error, background: AppColors.error.withValues(alpha: 0.1)),
                    title: const Text('Выйти', style: TextStyle(color: AppColors.error)),
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

  void _showChangePassword(BuildContext context) {
    final current = TextEditingController();
    final next = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Изменить пароль', style: Theme.of(sheetContext).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Текущий пароль')),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'Новый пароль')),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль обновлён')));
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: _tonalIcon(icon),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.green500,
    );
  }

  Widget _tonalIcon(IconData icon, {Color? color, Color? background}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: background ?? AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Icon(icon, color: color ?? AppColors.green600, size: 20),
    );
  }
}
