import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/recipe.dart';
import '../../../data/services/recipe_service.dart';
import 'food_ui.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});
  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _perServing = true;
  bool _busy = false;

  Future<void> _toggleFavorite(Recipe recipe) async {
    setState(() => _busy = true);
    try {
      await ref.read(recipeListProvider.notifier).toggleFavorite(recipe.id, !recipe.isFavorite);
      ref.invalidate(recipeDetailProvider(widget.recipeId));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить рецепт?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(recipeListProvider.notifier).delete(widget.recipeId);
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recipeDetailProvider(widget.recipeId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рецепт'),
        leading: const BackButton(),
        actions: [
          async.maybeWhen(
            data: (recipe) => Row(
              children: [
                IconButton(
                  onPressed: _busy ? null : () => _toggleFavorite(recipe),
                  icon: Icon(
                    recipe.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: recipe.isFavorite ? AppColors.error : null,
                  ),
                ),
                if (recipe.isOwner) ...[
                  IconButton(
                    onPressed: _busy ? null : () => context.push('/recipes/${recipe.id}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
                ],
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const LoadingView(),
          error: (err, st) => ErrorView(
            message: err is ApiException ? err.message : 'Не удалось загрузить рецепт',
            onRetry: () => ref.invalidate(recipeDetailProvider(widget.recipeId)),
          ),
          data: (recipe) => ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
            children: [
              _RecipeCover(recipe: recipe),
              const SizedBox(height: AppSpacing.lg),
              Text(recipe.name, style: Theme.of(context).textTheme.headlineMedium),
              if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(recipe.description!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _MetaChip(icon: Icons.people_outline_rounded, label: '${_formatServings(recipe.servings)} порц.'),
                  if (recipe.cookingTimeMinutes != null) ...[
                    const SizedBox(width: 8),
                    _MetaChip(icon: Icons.timer_outlined, label: '${recipe.cookingTimeMinutes} мин'),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Пищевая ценность', style: Theme.of(context).textTheme.titleSmall),
                        _NutritionToggle(perServing: _perServing, onChanged: (v) => setState(() => _perServing = v)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _NutritionRow(nutrients: _perServing ? recipe.nutritionPerServing : recipe.nutritionTotal),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Ингредиенты', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final ing in recipe.ingredients) ...[
                _IngredientRow(ingredient: ing),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Приготовление', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _Instructions(text: recipe.instructions),
            ],
          ),
        ),
      ),
    );
  }

  String _formatServings(double servings) => servings == servings.roundToDouble() ? servings.toStringAsFixed(0) : servings.toString();
}

class _RecipeCover extends StatelessWidget {
  const _RecipeCover({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final url = recipe.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: (url == null || url.isEmpty)
            ? Container(
                color: AppColors.green50,
                child: const Center(child: Icon(Icons.restaurant_menu_rounded, size: 48, color: AppColors.green500)),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.green50,
                  child: const Center(child: Icon(Icons.restaurant_menu_rounded, size: 48, color: AppColors.green500)),
                ),
              ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.ink100, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.ink500),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _NutritionToggle extends StatelessWidget {
  const _NutritionToggle({required this.perServing, required this.onChanged});
  final bool perServing;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool selected, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.green500 : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: selected ? Colors.white : AppColors.ink500)),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: AppColors.ink100, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment('На порцию', perServing, () => onChanged(true)),
          segment('Всего', !perServing, () => onChanged(false)),
        ],
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  const _NutritionRow({required this.nutrients});
  final RecipeNutrients nutrients;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );

    return Row(
      children: [
        stat('Калории', '${nutrients.calories}'),
        stat('Белки', '${nutrients.protein.toStringAsFixed(1)} г'),
        stat('Жиры', '${nutrients.fat.toStringAsFixed(1)} г'),
        stat('Углеводы', '${nutrients.carbohydrates.toStringAsFixed(1)} г'),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient});
  final RecipeIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    final quantityLabel = ingredient.quantity == ingredient.quantity.roundToDouble()
        ? ingredient.quantity.toStringAsFixed(0)
        : ingredient.quantity.toString();
    final showGrams = ingredient.unit == RecipeIngredientUnit.pcs;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          FoodThumbnail(id: ingredient.foodId, imageUrl: ingredient.foodImageUrl, emoji: ingredient.foodEmoji, size: 36, iconSize: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(ingredient.foodName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(
            showGrams ? '$quantityLabel ${ingredient.unit.label} (≈${ingredient.grams.round()} г)' : '$quantityLabel ${ingredient.unit.label}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final steps = text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (steps.length <= 1) {
      return Text(text, style: Theme.of(context).textTheme.bodyMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.green100, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green700)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(steps[i], style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
