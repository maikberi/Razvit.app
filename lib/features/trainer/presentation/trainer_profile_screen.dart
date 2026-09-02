import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../data/mock/mock_trainers.dart';
import '../../../data/models/trainer.dart';

class TrainerProfileScreen extends ConsumerWidget {
  const TrainerProfileScreen({super.key, required this.trainerId});
  final String trainerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainer = mockTrainers.firstWhere((t) => t.id == trainerId, orElse: () => mockTrainers.first);

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          children: [
            Center(child: AppAvatar(name: trainer.name, seed: trainer.avatarSeed, size: 88)),
            const SizedBox(height: AppSpacing.sm),
            Center(child: Text(trainer.name, style: Theme.of(context).textTheme.headlineMedium)),
            if (trainer.isVerified) const Center(child: Padding(padding: EdgeInsets.only(top: 6), child: VerifiedBadge())),
            const SizedBox(height: 4),
            Center(child: Text('Персональный тренер', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500))),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: _stat(context, '${trainer.rating}', 'Рейтинг')),
                Expanded(child: _stat(context, '${trainer.reviewsCount}', 'Отзывы')),
                Expanded(child: _stat(context, '${trainer.clientsCount}+', 'Клиенты')),
                Expanded(child: _stat(context, '${trainer.experienceYears}', 'Лет стажа')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('О тренере', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(trainer.bio, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Специализации', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final s in trainer.specializations) TagBadge(label: s.label, color: AppColors.green600)]),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: AppColors.green600),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Стоимость сопровождения', style: Theme.of(context).textTheme.bodyMedium)),
                  Text('${trainer.pricePerMonth} ₽/мес', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/chat/${trainer.id}'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Написать'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(onPressed: () => context.push('/chat/${trainer.id}'), child: const Text('Начать сопровождение')),
              ),
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
