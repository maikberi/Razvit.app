import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_repository.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  RecipeTag? _filter;

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
    final filtered = _filter == null ? recipes : recipes.where((r) => r.tags.contains(_filter)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Рецепты'), leading: const BackButton()),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                children: [
                  Padding(padding: const EdgeInsets.only(right: 8), child: SelectableChip(label: 'Все', selected: _filter == null, onTap: () => setState(() => _filter = null))),
                  for (final t in RecipeTag.values)
                    Padding(padding: const EdgeInsets.only(right: 8), child: SelectableChip(label: t.label, selected: _filter == t, onTap: () => setState(() => _filter = t))),
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
