import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/recipe.dart';
import '../../../data/services/recipe_service.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  static const _gradients = [
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFF22C55E), Color(0xFF16A34A)],
    [Color(0xFF3B82F6), Color(0xFF6366F1)],
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    [Color(0xFF06B6D4), Color(0xFF22C55E)],
    [Color(0xFFF97316), Color(0xFFF59E0B)],
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => ref.read(recipeListProvider.notifier).setQuery(value));
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipeListProvider);
    final notifier = ref.read(recipeListProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Рецепты'), leading: const BackButton()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/recipes/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Рецепт'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: TextField(
                  controller: _search,
                  onChanged: _onQueryChanged,
                  decoration: const InputDecoration(hintText: 'Найти рецепт', prefixIcon: Icon(Icons.search_rounded, color: AppColors.ink400)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: _SegmentButton(
                        label: 'Обзор',
                        selected: !notifier.favoritesOnly,
                        onTap: () => notifier.setFavoritesOnly(false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SegmentButton(
                        label: 'Избранное',
                        selected: notifier.favoritesOnly,
                        onTap: () => notifier.setFavoritesOnly(true),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: recipesAsync.when(
                  loading: () => const LoadingView(),
                  error: (err, st) => ErrorView(
                    message: err is ApiException ? err.message : 'Не удалось загрузить рецепты',
                    onRetry: notifier.refresh,
                  ),
                  data: (recipes) => recipes.isEmpty
                      ? EmptyState(
                          emoji: '🍳',
                          title: notifier.favoritesOnly ? 'Пока нет избранных рецептов' : 'Рецептов пока нет',
                          subtitle: notifier.favoritesOnly ? null : 'Нажмите «Рецепт», чтобы создать первый',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: recipes.length,
                          itemBuilder: (context, i) => _RecipeCard(recipe: recipes[i], gradient: _gradients[i % _gradients.length]),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.green500 : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.green500 : Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: selected ? Colors.white : null),
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.gradient});
  final Recipe recipe;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final imageUrl = recipe.imageUrl;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/recipes/${recipe.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                  child: (imageUrl == null || imageUrl.isEmpty)
                      ? Container(
                          decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                          child: const Center(child: Icon(Icons.restaurant_rounded, color: Colors.white70, size: 32)),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                            child: const Center(child: Icon(Icons.restaurant_rounded, color: Colors.white70, size: 32)),
                          ),
                        ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: _FavoriteButton(recipe: recipe),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (recipe.cookingTimeMinutes != null) ...[
                      const Icon(Icons.timer_outlined, size: 12, color: AppColors.ink400),
                      const SizedBox(width: 3),
                      Text('${recipe.cookingTimeMinutes} мин', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 8),
                    ],
                    const Icon(Icons.local_fire_department_outlined, size: 12, color: AppColors.ink400),
                    const SizedBox(width: 3),
                    Text('${recipe.nutritionPerServing.calories} ккал', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteButton extends ConsumerStatefulWidget {
  const _FavoriteButton({required this.recipe});
  final Recipe recipe;

  @override
  ConsumerState<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<_FavoriteButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(recipeListProvider.notifier).toggleFavorite(widget.recipe.id, !widget.recipe.isFavorite);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
        child: Icon(
          widget.recipe.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}
