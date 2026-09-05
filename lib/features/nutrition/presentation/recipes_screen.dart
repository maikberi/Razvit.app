import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_repository.dart';

IconData _tagIcon(RecipeTag t) => switch (t) {
      RecipeTag.breakfast => Icons.free_breakfast_rounded,
      RecipeTag.lunch => Icons.lunch_dining_rounded,
      RecipeTag.dinner => Icons.dinner_dining_rounded,
      RecipeTag.snack => Icons.cookie_rounded,
      RecipeTag.highProtein => Icons.egg_alt_rounded,
      RecipeTag.lowCalorie => Icons.eco_rounded,
    };

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  RecipeTag? _filter;
  bool _favoritesOnly = false;

  static const _gradients = [
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFF22C55E), Color(0xFF16A34A)],
    [Color(0xFF3B82F6), Color(0xFF6366F1)],
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    [Color(0xFF06B6D4), Color(0xFF22C55E)],
    [Color(0xFFF97316), Color(0xFFF59E0B)],
  ];

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    var filtered = _filter == null ? recipes : recipes.where((r) => r.tags.contains(_filter)).toList();
    if (_favoritesOnly) filtered = filtered.where((r) => r.isFavorite).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Рецепты'), leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(child: _SegmentButton(label: 'Обзор', selected: !_favoritesOnly, onTap: () => setState(() => _favoritesOnly = false))),
                  const SizedBox(width: 8),
                  Expanded(child: _SegmentButton(label: 'Избранное', selected: _favoritesOnly, onTap: () => setState(() => _favoritesOnly = true))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Категории', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  _CategoryTile(icon: Icons.apps_rounded, label: 'Все', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                  for (final t in RecipeTag.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _CategoryTile(icon: _tagIcon(t), label: t.label, selected: _filter == t, onTap: () => setState(() => _filter = t)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(emoji: '🍳', title: 'Рецептов не найдено')
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _RecipeCard(recipe: filtered[i], gradient: _gradients[filtered[i].colorSeed % _gradients.length]),
                    ),
            ),
          ],
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected ? AppColors.green500 : Theme.of(context).cardTheme.color,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.green500 : Theme.of(context).dividerColor),
              ),
              child: Icon(icon, color: selected ? Colors.white : AppColors.green600, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
          ],
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
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                  child: Container(
                    decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: const Center(child: Icon(Icons.restaurant_rounded, color: Colors.white70, size: 32)),
                  ),
                ),
                if (recipe.isNew || recipe.isPopular)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: TagBadge(label: recipe.isNew ? 'Новое' : 'Популярное', color: recipe.isNew ? AppColors.green500 : AppColors.warning),
                  ),
                if (recipe.isFavorite)
                  const Positioned(top: 8, right: 8, child: Icon(Icons.favorite_rounded, color: Colors.white, size: 18)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: AppColors.ink400),
                    const SizedBox(width: 3),
                    Text('${recipe.minutes} мин', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 8),
                    const Icon(Icons.local_fire_department_outlined, size: 12, color: AppColors.ink400),
                    const SizedBox(width: 3),
                    Text('${recipe.calories} ккал', style: Theme.of(context).textTheme.bodySmall),
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
