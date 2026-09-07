import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../data/models/nutrition.dart';
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
              child: ElevatedButton(onPressed: () => _showEditSheet(context, ref), child: const Text('Редактировать план')),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final plan = ref.read(nutritionPlanProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditPlanSheet(plan: plan),
    );
  }

  Widget _recommendation(BuildContext context, IconData icon, String title, String subtitle, {bool good = false}) {
    return AppCard(
      color: good ? (context.isDarkMode ? AppColors.green500.withValues(alpha: 0.18) : AppColors.green50) : null,
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

class _EditPlanSheet extends ConsumerStatefulWidget {
  const _EditPlanSheet({required this.plan});
  final NutritionPlan plan;

  @override
  ConsumerState<_EditPlanSheet> createState() => _EditPlanSheetState();
}

class _EditPlanSheetState extends ConsumerState<_EditPlanSheet> {
  late int _calories = widget.plan.calorieGoal;
  late int _protein = widget.plan.proteinGoal;
  late int _fat = widget.plan.fatGoal;
  late int _carbs = widget.plan.carbsGoal;
  late int _waterMl = widget.plan.waterGoalMl;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Редактировать план', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            _stepperRow('Калории', '$_calories ккал', () => setState(() => _calories = (_calories - 50).clamp(1000, 5000)), () => setState(() => _calories = (_calories + 50).clamp(1000, 5000))),
            _stepperRow('Белки', '$_protein г', () => setState(() => _protein = (_protein - 5).clamp(20, 400)), () => setState(() => _protein = (_protein + 5).clamp(20, 400))),
            _stepperRow('Жиры', '$_fat г', () => setState(() => _fat = (_fat - 5).clamp(10, 300)), () => setState(() => _fat = (_fat + 5).clamp(10, 300))),
            _stepperRow('Углеводы', '$_carbs г', () => setState(() => _carbs = (_carbs - 5).clamp(20, 600)), () => setState(() => _carbs = (_carbs + 5).clamp(20, 600))),
            _stepperRow(
              'Вода',
              '${(_waterMl / 1000).toStringAsFixed(1)} л',
              () => setState(() => _waterMl = (_waterMl - 100).clamp(500, 6000)),
              () => setState(() => _waterMl = (_waterMl + 100).clamp(500, 6000)),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(nutritionPlanProvider.notifier).update(
                        calorieGoal: _calories,
                        proteinGoal: _protein,
                        fatGoal: _fat,
                        carbsGoal: _carbs,
                        waterGoalMl: _waterMl,
                      );
                  Navigator.of(context).pop();
                },
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperRow(String label, String value, VoidCallback onMinus, VoidCallback onPlus) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          IconButton.filled(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded),
            style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
          ),
          SizedBox(width: 84, child: Text(value, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall)),
          IconButton.filled(
            onPressed: onPlus,
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
          ),
        ],
      ),
    );
  }
}
