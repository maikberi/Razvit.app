import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_day_repository.dart';
import '../../../data/services/food_service.dart';
import 'barcode_scanner_screen.dart';
import 'food_ui.dart';

/// Экран поиска продукта для добавления в конкретный приём пищи
/// ([mealId] — реальный id из backend). Все данные — из Food Database
/// backend (локальный каталог RAZVIT + автоматически подтянутые
/// USDA/Open Food Facts), никакого мок-каталога.
class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key, required this.mealId, required this.mealType});

  final String mealId;
  final MealType mealType;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<FoodItem> _results = [];
  int _page = 1;
  int _totalPages = 1;
  bool _searching = false;
  bool _loadingMore = false;
  String? _searchError;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    // Бесконечная прокрутка: следующая страница подгружается сама, когда
    // список долистали почти до конца — без отдельной кнопки "Показать ещё".
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_searching || _loadingMore || _searchError != null || _page >= _totalPages) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _runSearch(reset: false);
    }
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < FoodService.minQueryLength) {
      setState(() {
        _results = [];
        _searchError = null;
        _page = 1;
        _totalPages = 1;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _runSearch(reset: true));
  }

  Future<void> _runSearch({required bool reset}) async {
    final trimmed = _search.text.trim();
    if (trimmed.length < FoodService.minQueryLength) return;

    setState(() {
      if (reset) {
        _searching = true;
        _page = 1;
      } else {
        _loadingMore = true;
      }
      _searchError = null;
    });

    try {
      final page = reset ? 1 : _page + 1;
      final result = await ref.read(foodServiceProvider).search(trimmed, page: page);
      if (!mounted) return;
      setState(() {
        _results = reset ? result.items : [..._results, ...result.items];
        _page = result.page;
        _totalPages = result.totalPages;
        _searching = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.message;
        _searching = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _addFood(FoodItem food, int grams) async {
    setState(() => _adding = true);
    try {
      await ref.read(nutritionDayProvider.notifier).addFoodItem(mealId: widget.mealId, foodId: food.id, grams: grams.toDouble());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${food.name} добавлено')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Добавить продукт · ${widget.mealType.label}'), leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: const InputDecoration(hintText: 'Найти продукт', prefixIcon: Icon(Icons.search_rounded, color: AppColors.ink400)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showBarcodeLookup(context),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Ввести по штрихкоду'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_adding) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _search.text.trim().length < FoodService.minQueryLength
                  ? const EmptyState(emoji: '🔍', title: 'Начни вводить название', subtitle: 'Например: «курица», «овсянка», «яблоко»')
                  : _results.isEmpty && !_searching && _searchError == null
                      ? const EmptyState(emoji: '🍽️', title: 'Продукт не найден', subtitle: 'Попробуй изменить запрос или введи вручную')
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                          children: [
                            if (_searching)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                            for (final f in _results) ...[
                              _FoodRow(food: f, onAdd: (grams) => _addFood(f, grams)),
                              const SizedBox(height: 8),
                            ],
                            if (_searchError != null)
                              _OnlineErrorRow(message: _searchError!, onRetry: () => _runSearch(reset: _results.isEmpty)),
                            if (_searchError == null && _loadingMore)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                              ),
                            if (_searchError == null && !_searching && !_loadingMore && _page >= _totalPages && _results.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                                child: Center(
                                  child: Text('Это все найденные продукты', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink400)),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBarcodeLookup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BarcodeScannerScreen(onAdd: (food, grams) => _addFood(food, grams))),
    );
  }
}

class BarcodeSheet extends ConsumerStatefulWidget {
  const BarcodeSheet({super.key, required this.controller, required this.onAdd});
  final TextEditingController controller;
  final void Function(FoodItem food, int grams) onAdd;

  @override
  ConsumerState<BarcodeSheet> createState() => _BarcodeSheetState();
}

class _BarcodeSheetState extends ConsumerState<BarcodeSheet> {
  bool _loading = false;
  bool _notFound = false;
  String? _error;
  FoodItem? _found;

  static final _validBarcode = RegExp(r'^\d{6,14}$');

  Future<void> _lookup() async {
    final code = widget.controller.text.trim();
    if (code.isEmpty) return;
    if (!_validBarcode.hasMatch(code)) {
      setState(() {
        _loading = false;
        _notFound = false;
        _found = null;
        _error = 'Некорректный штрихкод — только цифры, от 6 до 14 знаков';
      });
      return;
    }
    setState(() {
      _loading = true;
      _notFound = false;
      _error = null;
      _found = null;
    });
    try {
      final result = await ref.read(foodServiceProvider).lookupBarcode(code);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _found = result;
        _notFound = result == null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
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
            'Введи номер штрихкода — найдём продукт в базе RAZVIT',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
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
          if (_error != null) _OnlineErrorRow(message: _error!, onRetry: _lookup),
          if (_found != null) _FoodRow(food: _found!, onAdd: (grams) async => widget.onAdd(_found!, grams)),
        ],
      ),
    );
  }
}

/// Компактная строка ошибки сети/сервера с кнопкой "Повторить" —
/// используется и в онлайн-поиске, и в поиске по штрихкоду.
class _OnlineErrorRow extends StatelessWidget {
  const _OnlineErrorRow({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error))),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

class _FoodRow extends StatefulWidget {
  const _FoodRow({required this.food, required this.onAdd});
  final FoodItem food;
  final Future<void> Function(int grams) onAdd;

  @override
  State<_FoodRow> createState() => _FoodRowState();
}

class _FoodRowState extends State<_FoodRow> {
  int _addedCount = 0;
  bool _busy = false;

  Future<void> _handleQuickAdd() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAdd(widget.food.defaultGrams);
      if (mounted) setState(() => _addedCount++);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => ProductDetailSheet(food: food, onAdd: (grams) => widget.onAdd(grams)),
      ),
      child: Row(
        children: [
          FoodThumbnail(id: food.id, imageUrl: food.imageUrl, emoji: food.emoji, size: 44, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(food.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                if (food.brand != null && food.brand!.isNotEmpty)
                  Text(food.brand!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${food.defaultGrams}${food.basisUnit.label} · ${food.caloriesPer100g} ккал',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _QuickAddButton(busy: _busy, addedCount: _addedCount, onTap: _handleQuickAdd),
        ],
      ),
    );
  }
}

/// Кнопка быстрого добавления продукта прямо из списка поиска — до
/// первого нажатия она нейтральная (не зелёная), чтобы не выглядеть, будто
/// продукт уже добавлен. Зелёной становится только после реального
/// добавления, а повторные нажатия добавляют ещё по одной порции и
/// увеличивают счётчик — как "2 раза нажали — 2 раза добавило".
class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.busy, required this.addedCount, required this.onTap});
  final bool busy;
  final int addedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final added = addedCount > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filled(
          onPressed: busy ? null : onTap,
          icon: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(
            backgroundColor: added ? AppColors.green500 : AppColors.ink100,
            foregroundColor: added ? Colors.white : AppColors.ink600,
          ),
        ),
        if (added)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: AppColors.green700, borderRadius: BorderRadius.circular(10)),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                '×$addedCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class ProductDetailSheet extends StatefulWidget {
  const ProductDetailSheet({super.key, required this.food, required this.onAdd});
  final FoodItem food;
  final ValueChanged<int> onAdd;

  @override
  State<ProductDetailSheet> createState() => ProductDetailSheetState();
}

class ProductDetailSheetState extends State<ProductDetailSheet> {
  late int _grams = widget.food.defaultGrams;

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final ratio = _grams / 100;
    final unit = food.basisUnit.label;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FoodThumbnail(id: food.id, imageUrl: food.imageUrl, emoji: food.emoji, size: 64, iconSize: 30, onTap: foodPhotoTap(context, food.imageUrl)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: Theme.of(context).textTheme.headlineMedium),
                    if (food.brand != null && food.brand!.isNotEmpty)
                      Text(food.brand!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
                    Text('$_grams $unit', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _statColumn(context, 'Калории', '${(food.caloriesPer100g * ratio).round()}')),
              Expanded(child: _statColumn(context, 'Белки', '${(food.proteinPer100g * ratio).toStringAsFixed(0)} г')),
              Expanded(child: _statColumn(context, 'Жиры', '${(food.fatPer100g * ratio).toStringAsFixed(0)} г')),
              Expanded(child: _statColumn(context, 'Углеводы', '${(food.carbsPer100g * ratio).toStringAsFixed(0)} г')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Вес порции', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: _grams > 10 ? () => setState(() => _grams -= 10) : null,
                icon: const Icon(Icons.remove_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
              ),
              SizedBox(width: 100, child: Text('$_grams $unit', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium)),
              IconButton.filled(
                onPressed: () => setState(() => _grams += 10),
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
              ),
            ],
          ),
          if (food.servingUnit != null && food.servingUnit!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _grams = food.defaultGrams),
                child: Text('1 порция · ${food.defaultGrams} $unit (${food.servingUnit})'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onAdd(_grams);
              },
              child: const Text('Добавить продукт'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Пищевая ценность на 100 $unit', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          _nutrientRow(context, 'Калории', '${food.caloriesPer100g} ккал'),
          _nutrientRow(context, 'Белки', '${food.proteinPer100g.toStringAsFixed(1)} г'),
          _nutrientRow(context, 'Жиры', '${food.fatPer100g.toStringAsFixed(1)} г'),
          _nutrientRow(context, 'Углеводы', '${food.carbsPer100g.toStringAsFixed(1)} г'),
          _nutrientRow(context, 'Клетчатка', '${food.fiberPer100g.toStringAsFixed(1)} г'),
          if (food.sugarPer100g != null) _nutrientRow(context, 'Сахар', '${food.sugarPer100g!.toStringAsFixed(1)} г'),
          if (food.sodiumPer100g != null) _nutrientRow(context, 'Натрий', '${food.sodiumPer100g!.toStringAsFixed(0)} мг'),
          if (food.micronutrients.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Микроэлементы', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final entry in food.micronutrients.entries)
              _nutrientRow(context, entry.key, '${entry.value.amount.toStringAsFixed(1)} ${entry.value.unit}'),
          ],
        ],
      ),
    );
  }

  Widget _statColumn(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _nutrientRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
