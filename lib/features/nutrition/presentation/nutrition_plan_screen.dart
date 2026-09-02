import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/repositories/nutrition_repository.dart';

class NutritionPlanScreen extends ConsumerWidget {
  const NutritionPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(nutritionPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('План питания'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppCard(
              color: AppColors.ink900,
              shadow: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text('Твой план', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(plan.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    '${plan.calorieGoal} ккал · Б ${plan.proteinGoal} г · Ж ${plan.fatGoal} г · У ${plan.carbsGoal} г',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text('Действует до ${DateFormat('d MMMM yyyy', 'ru').format(plan.validUntil)}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(value: plan.progressPercent / 100, minHeight: 6, backgroundColor: Colors.white12, color: AppColors.green500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Рекомендации', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _recommendation(context, Icons.water_drop_outlined, 'Пей больше воды', 'Ты выпил 1.6 л из 2.5 л'),
            const SizedBox(height: 8),
            _recommendation(context, Icons.egg_alt_outlined, 'Больше белка', 'Добавь 20 г белка к цели'),
            const SizedBox(height: 8),
            _recommendation(context, Icons.check_circle_outline_rounded, 'Отличный баланс', 'Ты хорошо распределяешь БЖУ!', good: true),
            const SizedBox(height: AppSpacing.lg),
            Text('Цель', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Row(
                children: [
                  ProgressRing(
                    progress: plan.progressPercent / 100,
                    size: 84,
                    child: Text('${plan.progressPercent}%', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text('Ты на верном пути! Ещё немного и цель будет достигнута.', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () {}, child: const Text('Редактировать план')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendation(BuildContext context, IconData icon, String title, String subtitle, {bool good = false}) {
    return AppCard(
      color: good ? AppColors.green50 : AppColors.white,
      shadow: !good,
      child: Row(
        children: [
          Icon(icon, color: good ? AppColors.green600 : AppColors.info),
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
        ],
      ),
    );
  }
}
