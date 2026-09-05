import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_repository.dart';
import '../../../data/services/open_food_facts_service.dart';

class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key, required this.mealType});

  final String mealType;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<FoodItem> _onlineResults = [];
  bool _searchingOnline = false;

  MealType get _type => MealType.values.firstWhere((t) => t.name == widget.mealType, orElse: () => MealType.snack);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      setState(() => _onlineResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _searchingOnline = true);
      final results = await OpenFoodFactsService.search(trimmed);
      if (!mounted) return;
      setState(() {
        _onlineResults = results;
        _searchingOnline = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final foods = ref.watch(foodCatalogProvider);
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty ? foods : foods.where((f) => f.name.toLowerCase().contains(query)).toList();
    final localIds = filtered.map((f) => f.id).toSet();
    final onlineExtra = _onlineResults.where((f) => !localIds.contains(f.id)).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Добавить продукт · ${_type.label}'), leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _search,
                onChanged: _onQueryChanged,
                decoration: const InputDecoration(hintText: 'Найти продукт', prefixIcon: Icon(Icons.search_rounded, color: AppColors.ink400)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showBarcodeLookup(context),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Штрихкод'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showPhotoPlaceholder(context),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Фото'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: filtered.isEmpty && onlineExtra.isEmpty && !_searchingOnline
                  ? const EmptyState(emoji: '🍽️', title: 'Продукт не найден', subtitle: 'Попробуй изменить запрос')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                      children: [
                        for (final f in filtered) ...[
                          _FoodRow(food: f, onAdd: (grams) => _addFood(f, grams)),
                          const SizedBox(height: 8),
                        ],
                        if (_searchingOnline || onlineExtra.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Text('Найдено в базе продуктов', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.ink500)),
                              if (_searchingOnline) ...[
                                const SizedBox(width: 8),
                                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final f in onlineExtra) ...[
                            _FoodRow(food: f, onAdd: (grams) => _addFood(f, grams)),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
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

  void _showPhotoPlaceholder(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Добавление по фотографии', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(color: AppColors.ink900, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: const Center(child: Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 64)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Наведи камеру на блюдо — RAZVIT определит калорийность',
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

  void _showBarcodeLookup(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _BarcodeSheet(
        controller: controller,
        onAdd: (food, grams) {
          Navigator.of(sheetContext).pop();
          _addFood(food, grams);
        },
      ),
    );
  }
}

class _BarcodeSheet extends StatefulWidget {
  const _BarcodeSheet({required this.controller, required this.onAdd});
  final TextEditingController controller;
  final void Function(FoodItem food, int grams) onAdd;

  @override
  State<_BarcodeSheet> createState() => _BarcodeSheetState();
}

class _BarcodeSheetState extends State<_BarcodeSheet> {
  bool _loading = false;
  bool _notFound = false;
  FoodItem? _found;

  Future<void> _lookup() async {
    final code = widget.controller.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _notFound = false;
      _found = null;
    });
    final result = await OpenFoodFactsService.lookupBarcode(code);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _found = result;
      _notFound = result == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Поиск по штрихкоду', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Введи номер штрихкода — найдём продукт в открытой базе Open Food Facts',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Например, 4600000000000'),
                  onSubmitted: (_) => _lookup(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _loading ? null : _lookup,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.green500, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_notFound)
            Text('Продукт не найден. Попробуй другой штрихкод или добавь вручную.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error)),
          if (_found != null) _FoodRow(food: _found!, onAdd: (grams) => widget.onAdd(_found!, grams)),
        ],
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
