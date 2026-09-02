import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_repository.dart';

class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key, required this.mealType});

  final String mealType;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _search = TextEditingController();

  MealType get _type => MealType.values.firstWhere((t) => t.name == widget.mealType, orElse: () => MealType.snack);

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodCatalogProvider);
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty ? foods : foods.where((f) => f.name.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Добавить продукт · ${_type.label}'), leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Найти продукт', prefixIcon: Icon(Icons.search_rounded, color: AppColors.ink400)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showScanner(context),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Штрихкод'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showScanner(context, photo: true),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Фото'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(emoji: '🍽️', title: 'Продукт не найден', subtitle: 'Попробуй изменить запрос')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _FoodRow(food: filtered[i], onAdd: (grams) => _addFood(filtered[i], grams)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _addFood(FoodItem food, int grams) {
    ref.read(mealsProvider.notifier).addFood(_type, food, grams);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${food.name} добавлено')));
  }

  void _showScanner(BuildContext context, {bool photo = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(photo ? 'Добавление по фотографии' : 'Сканер штрихкода', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(color: AppColors.ink900, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Center(
                  child: Icon(photo ? Icons.camera_alt_rounded : Icons.qr_code_scanner_rounded, color: Colors.white38, size: 64),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              photo ? 'Наведи камеру на блюдо — RAZVIT определит калорийность' : 'Наведи камеру на штрихкод продукта',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Закрыть')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.onAdd});
  final FoodItem food;
  final ValueChanged<int> onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${food.defaultGrams} г · ${food.caloriesPer100g} ккал',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Б ${food.proteinPer100g.toStringAsFixed(1)} · Ж ${food.fatPer100g.toStringAsFixed(1)} · У ${food.carbsPer100g.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: () => onAdd(food.defaultGrams),
            icon: const Icon(Icons.add_rounded),
            style: IconButton.styleFrom(backgroundColor: AppColors.green500, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
