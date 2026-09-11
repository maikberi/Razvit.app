import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';

class _NotificationItem {
  const _NotificationItem(this.emoji, this.title, this.subtitle, this.time);
  final String emoji;
  final String title;
  final String subtitle;
  final String time;
}

const _items = [
  _NotificationItem('💪', 'Пора тренироваться', 'Push Day начинается через 30 минут', '2 ч назад'),
  _NotificationItem('🔥', 'Новый личный рекорд!', 'Жим лёжа — 100 кг × 10', 'Вчера'),
  _NotificationItem('💧', 'Не забудь про воду', 'Сегодня выпито всего 1.6 л из 2.5 л', 'Вчера'),
  _NotificationItem('👨‍🏫', 'Новое сообщение от тренера', 'Алексей Иванов оставил комментарий к тренировке', '2 дня назад'),
  _NotificationItem('🏆', 'Достижение получено', '7 дней подряд — отличная серия!', '3 дня назад'),
];

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления'), leading: const BackButton()),
      body: _items.isEmpty
          ? const EmptyState(emoji: '🔔', title: 'Пока нет уведомлений', subtitle: 'Здесь будут напоминания и важные события')
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final item = _items[i];
                return AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Text(item.time, style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
