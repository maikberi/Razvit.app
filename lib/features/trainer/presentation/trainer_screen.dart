import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/trainer.dart';
import '../../../data/repositories/trainer_repository.dart';

class TrainerScreen extends ConsumerStatefulWidget {
  const TrainerScreen({super.key});

  @override
  ConsumerState<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends ConsumerState<TrainerScreen> {
  TrainerSpecialization? _filter;

  @override
  Widget build(BuildContext context) {
    final trainers = ref.watch(trainersProvider);
    final myTrainer = ref.watch(myTrainerProvider);
    final filtered = _filter == null ? trainers : trainers.where((t) => t.specializations.contains(_filter)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Тренеры')),
      body: SafeArea(
        child: trainers.isEmpty
            ? EmptyState(
                emoji: '🧑‍🏫',
                title: 'Найди специалиста',
                subtitle: 'Который поможет тебе быстрее достичь цели',
                actionLabel: 'Найти тренера',
                onAction: () {},
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  AppCard(
                    onTap: () => context.push('/trainer/${myTrainer.id}'),
                    child: Row(
                      children: [
                        AppAvatar(name: myTrainer.name, seed: myTrainer.avatarSeed, size: 52),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [Text('Мой тренер', style: Theme.of(context).textTheme.bodySmall), const SizedBox(width: 6), const VerifiedBadge(compact: true)]),
                              Text(myTrainer.name, style: Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.push('/chat/${myTrainer.id}'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.green600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Найти тренера', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(padding: const EdgeInsets.only(right: 8), child: SelectableChip(label: 'Все', selected: _filter == null, onTap: () => setState(() => _filter = null))),
                        for (final s in TrainerSpecialization.values)
                          Padding(padding: const EdgeInsets.only(right: 8), child: SelectableChip(label: s.label, selected: _filter == s, onTap: () => setState(() => _filter = s))),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final t in filtered) ...[
                    _TrainerListCard(trainer: t),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
      ),
    );
  }
}

class _TrainerListCard extends StatelessWidget {
  const _TrainerListCard({required this.trainer});
  final Trainer trainer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/trainer/${trainer.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  AppAvatar(name: trainer.name, seed: trainer.avatarSeed, size: 56),
                  if (trainer.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(width: 13, height: 13, decoration: BoxDecoration(color: AppColors.green500, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Expanded(child: Text(trainer.name, style: Theme.of(context).textTheme.titleSmall)), if (trainer.isVerified) const VerifiedBadge(compact: true)]),
                    const SizedBox(height: 2),
                    Text('★ ${trainer.rating} · ${trainer.reviewsCount} отзывов · ${trainer.clientsCount}+ клиентов', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final s in trainer.specializations.take(3)) TagBadge(label: s.label, color: AppColors.ink700)]),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text('${trainer.pricePerMonth} ₽/мес', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Icon(Icons.schedule_rounded, size: 14, color: AppColors.ink400),
              const SizedBox(width: 4),
              Text('Ответ ${trainer.responseTime}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
