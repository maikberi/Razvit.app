import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/services/food_service.dart';
import 'food_ui.dart';

/// Экран выбора продукта для ингредиента рецепта — тот же поиск, что и
/// при добавлении в приём пищи, но результат просто возвращается вызвавшему
/// экрану (без порции/приёма пищи — граммовку и единицу рецепт спрашивает
/// сам, на форме ингредиента).
class RecipeIngredientPickerScreen extends ConsumerStatefulWidget {
  const RecipeIngredientPickerScreen({super.key});

  @override
  ConsumerState<RecipeIngredientPickerScreen> createState() => _RecipeIngredientPickerScreenState();
}

class _RecipeIngredientPickerScreenState extends ConsumerState<RecipeIngredientPickerScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  List<FoodItem> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < FoodService.minQueryLength) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _runSearch(trimmed));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await ref.read(foodServiceProvider).search(query);
      if (!mounted) return;
      setState(() {
        _results = result.items;
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить ингредиент'), leading: const BackButton()),
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
            Expanded(
              child: _search.text.trim().length < FoodService.minQueryLength
                  ? const EmptyState(emoji: '🥗', title: 'Начни вводить название', subtitle: 'Например: «курица», «рис», «яйцо»')
                  : _searching
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? EmptyState(emoji: '⚠️', title: 'Не удалось найти', subtitle: _error!)
                          : _results.isEmpty
                              ? const EmptyState(emoji: '🍽️', title: 'Продукт не найден')
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                                  itemCount: _results.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final food = _results[i];
                                    return AppCard(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      onTap: () => Navigator.of(context).pop(food),
                                      child: Row(
                                        children: [
                                          FoodThumbnail(id: food.id, imageUrl: food.imageUrl, emoji: food.emoji, size: 40, iconSize: 18),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(food.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                if (food.brand != null && food.brand!.isNotEmpty)
                                                  Text(food.brand!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                Text('${food.caloriesPer100g} ккал / 100 ${food.basisUnit.label}', style: Theme.of(context).textTheme.bodySmall),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
                                        ],
                                      ),
                                    );
                                  },
                                ),
            ),
          ],
        ),
      ),
    );
  }
}
