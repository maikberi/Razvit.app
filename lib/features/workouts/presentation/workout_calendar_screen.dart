import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/workout_session.dart';
import '../../../data/repositories/workout_repository.dart';

class WorkoutCalendarScreen extends ConsumerStatefulWidget {
  const WorkoutCalendarScreen({super.key});

  @override
  ConsumerState<WorkoutCalendarScreen> createState() => _WorkoutCalendarScreenState();
}

class _WorkoutCalendarScreenState extends ConsumerState<WorkoutCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(workoutSessionsProvider);
    WorkoutSession? sessionFor(DateTime day) {
      final d = DateTime(day.year, day.month, day.day);
      final matches = sessions.where((s) => DateTime(s.date.year, s.date.month, s.date.day) == d);
      return matches.isEmpty ? null : matches.first;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Календарь тренировок'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
              child: TableCalendar<WorkoutSession>(
                locale: 'ru_RU',
                startingDayOfWeek: StartingDayOfWeek.monday,
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 60)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                  final session = sessionFor(selected);
                  _showDaySheet(context, selected, session);
                },
                onPageChanged: (focused) => _focusedDay = focused,
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                calendarStyle: const CalendarStyle(outsideDaysVisible: false),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) => _buildDay(context, day, sessionFor(day)),
                  todayBuilder: (context, day, focusedDay) => _buildDay(context, day, sessionFor(day), isToday: true),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _legend(AppColors.green500, 'Выполнено'),
                const SizedBox(width: 16),
                _legend(AppColors.ink300, 'Запланировано'),
                const SizedBox(width: 16),
                _legend(AppColors.error, 'Пропущено'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDay(BuildContext context, DateTime day, WorkoutSession? session, {bool isToday = false}) {
    Color color = Colors.transparent;
    switch (session?.status) {
      case SessionStatus.done:
        color = AppColors.green500;
      case SessionStatus.missed:
        color = AppColors.error;
      case SessionStatus.planned:
        color = AppColors.ink300;
      case null:
        color = Colors.transparent;
    }
    return Center(
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: AppColors.green600, width: 2) : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text('${day.day}', style: TextStyle(color: AppColors.ink900, fontWeight: isToday ? FontWeight.w800 : FontWeight.w500)),
            if (color != Colors.transparent)
              Positioned(
                bottom: 0,
                child: Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  void _showDaySheet(BuildContext context, DateTime day, WorkoutSession? session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('d MMMM', 'ru').format(day), style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              if (session == null)
                Text('Тренировок не запланировано', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500))
              else ...[
                Row(
                  children: [
                    Text(session.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                    _StatusChip(status: session.status),
                  ],
                ),
                if (session.status == SessionStatus.done) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(child: _stat(context, '${session.durationMinutes}', 'минут')),
                      Expanded(child: _stat(context, '${session.calories}', 'ккал')),
                      Expanded(child: _stat(context, '${session.volumeKg.round()}', 'кг объём')),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SessionStatus.done => ('Выполнено', AppColors.green500),
      SessionStatus.missed => ('Пропущено', AppColors.error),
      SessionStatus.planned => ('Запланировано', AppColors.ink500),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
