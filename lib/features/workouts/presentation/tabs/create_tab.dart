import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../data/repositories/workout_repository.dart';
import '../../widgets/program_card.dart';

class CreateTab extends ConsumerWidget {
  const CreateTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customPrograms = ref.watch(allProgramsProvider).where((p) => p.isCustom).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      children: [
        if (customPrograms.isEmpty)
          EmptyState(
            emoji: '🏗️',
            title: 'Создай свою первую программу',
            subtitle: 'Выбери дни, добавь упражнения и RAZVIT соберёт для тебя расписание',
            actionLabel: 'Создать программу',
            onAction: () => context.push('/create-program'),
          )
        else ...[
          Text('Мои программы', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final p in customPrograms) ...[
            ProgramCard(program: p),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/create-program'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Создать ещё одну программу'),
            ),
          ),
        ],
      ],
    );
  }
}
