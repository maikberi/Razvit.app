import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/workout_session.dart';

const _weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

class WeekStripCard extends StatelessWidget {
  const WeekStripCard({super.key, required this.sessions, required this.streakDays});

  final List<WorkoutSession> sessions;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Эта неделя', style: Theme.of(context).textTheme.titleMedium),
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text('$streakDays дней подряд', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.ink600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final date = monday.add(Duration(days: i));
              final isToday = date == today;
              final session = sessions.where((s) {
                final d = DateTime(s.date.year, s.date.month, s.date.day);
                return d == date;
              }).firstOrNull;

              return Column(
                children: [
                  Text(_weekdayLabels[i], style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  _DayDot(status: session?.status, isToday: isToday, isFuture: date.isAfter(today)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.status, required this.isToday, required this.isFuture});
  final SessionStatus? status;
  final bool isToday;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.ink100;
    Widget? icon;

    switch (status) {
      case SessionStatus.done:
        bg = AppColors.green500;
        icon = const Icon(Icons.check_rounded, color: Colors.white, size: 16);
      case SessionStatus.missed:
        bg = AppColors.error;
        icon = const Icon(Icons.close_rounded, color: Colors.white, size: 16);
      case SessionStatus.planned:
        bg = AppColors.white;
        icon = null;
      case null:
        bg = AppColors.ink100;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday ? AppColors.green600 : (status == SessionStatus.planned ? AppColors.ink300 : Colors.transparent),
          width: isToday ? 2 : 1,
        ),
      ),
      child: icon,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
