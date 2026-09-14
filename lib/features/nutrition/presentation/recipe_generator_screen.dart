import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/models/recipe.dart';
import '../../../data/models/recipe_generator.dart';
import '../../../data/repositories/nutrition_day_repository.dart';
import '../../../data/services/recipe_generator_service.dart';
import '../../../data/services/recipe_service.dart';
import 'food_ui.dart';
import 'recipe_ingredient_picker_screen.dart';

enum _Stage { idle, generating, error, result }

const _suggestions = [
  'Ужин до 600 ккал и минимум 40 г белка',
  'Лёгкий завтрак до 350 ккал',
  'Перекус с высоким белком без сахара',
  'Обед на 500 ккал с курицей и овощами',
];

/// AI Recipe Generator — пользователь описывает, что хочет, свободным
/// текстом ("Хочу ужин до 600 ккал и минимум 40 г белка"), AI придумывает
/// название/ингредиенты/инструкцию (и распознаёт числовые ограничения из
/// текста), а backend считает реальные КБЖУ через Food Database + Nutrition
/// Engine и, если AI промахнулся мимо ограничений, сам пересчитывает порцию
/// (см. recipeGenerator.service.ts). AI никогда не источник истины для КБЖУ.
class RecipeGeneratorScreen extends ConsumerStatefulWidget {
  const RecipeGeneratorScreen({super.key});

  @override
  ConsumerState<RecipeGeneratorScreen> createState() => _RecipeGeneratorScreenState();
}

class _RecipeGeneratorScreenState extends ConsumerState<RecipeGeneratorScreen> {
  final _promptController = TextEditingController();
  _Stage _stage = _Stage.idle;
  GeneratedRecipe? _recipe;
  String? _errorMessage;
  bool _saving = false;
  bool _addingToDiary = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.length < 3) return;
    setState(() {
      _stage = _Stage.generating;
      _errorMessage = null;
    });
    try {
      final recipe = await ref.read(recipeGeneratorServiceProvider).generate(prompt);
      if (!mounted) return;
      setState(() {
        _recipe = recipe;
        _stage = _Stage.result;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage = _messageFor(e);
      });
    }
  }

  String _messageFor(ApiException e) {
    if (e.isNetworkError) return 'Нет соединения с сервером. Проверь интернет и попробуй снова.';
    return switch (e.code) {
      'AI_NOT_CONFIGURED' => 'Генерация рецептов пока недоступна.',
      'AI_TIMEOUT' => 'Придумывание рецепта заняло слишком много времени. Попробуй ещё раз.',
      'AI_RATE_LIMITED' => 'Слишком много запросов. Попробуй через минуту.',
      'AI_UNAVAILABLE' => 'Сервис генерации рецептов временно недоступен. Попробуй позже.',
      _ => e.message,
    };
  }

  void _retry() => setState(() => _stage = _Stage.idle);

  Future<void> _resolveIngredient(int index) async {
    final food = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(builder: (_) => const RecipeIngredientPickerScreen()),
    );
    if (food == null || _recipe == null) return;
    final updated = _recipe!.ingredients[index].withManualMatch(
      foodId: food.id,
      foodName: food.name,
      foodImageUrl: food.imageUrl,
      foodEmoji: food.emoji,
    );
    setState(() => _recipe = _recipe!.withIngredient(index, updated));
  }

  Future<void> _saveRecipe() async {
    final recipe = _recipe;
    if (recipe == null || recipe.hasUnresolvedIngredients || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(recipeServiceProvider).create(
            name: recipe.name,
            description: recipe.description,
            servings: recipe.servings,
            cookingTimeMinutes: recipe.cookingTimeMinutes,
            instructions: recipe.instructions,
            ingredients: recipe.ingredients
                .map((i) => RecipeIngredientDraft(foodId: i.matchedFoodId!, quantity: i.quantity, unit: i.unit))
                .toList(),
          );
      unawaited(ref.read(recipeListProvider.notifier).refresh());
      if (!mounted) return;
      context.pushReplacement('/recipes/${saved.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
  }

  Future<void> _pickMealAndAddToDiary() async {
    final recipe = _recipe;
    if (recipe == null || recipe.hasUnresolvedIngredients || _addingToDiary) return;
    final type = await showModalBottomSheet<MealType>(
      context: context,
      builder: (context) => _MealTypePickerSheet(),
    );
    if (type == null || !mounted) return;
    await _addToDiary(type);
  }

  Future<void> _addToDiary(MealType type) async {
    final recipe = _recipe;
    if (recipe == null) return;
    final day = ref.read(nutritionDayProvider).valueOrNull;
    if (day == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Данные дня ещё загружаются, попробуй через секунду')));
      return;
    }
    final mealId = day.mealOf(type).id;
    final servings = recipe.servings <= 0 ? 1 : recipe.servings;

    setState(() => _addingToDiary = true);
    try {
      for (final ing in recipe.ingredients) {
        if (!ing.isResolved) continue;
        await ref.read(nutritionDayProvider.notifier).addFoodItem(
              mealId: mealId,
              foodId: ing.matchedFoodId,
              name: ing.matchedFoodName,
              grams: ing.grams / servings,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Рецепт добавлен в «${type.label.toLowerCase()}»')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _addingToDiary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI рецепт'), leading: const BackButton()),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.idle => _PromptView(controller: _promptController, onGenerate: _generate),
          _Stage.generating => const _GeneratingView(),
          _Stage.error => _ErrorView(message: _errorMessage ?? 'Что-то пошло не так', onRetry: _retry),
          _Stage.result => _ResultView(
              recipe: _recipe!,
              saving: _saving,
              addingToDiary: _addingToDiary,
              onResolveIngredient: _resolveIngredient,
              onSave: _saveRecipe,
              onAddToDiary: _pickMealAndAddToDiary,
              onRegenerate: _retry,
            ),
        },
      ),
    );
  }
}

class _PromptView extends StatelessWidget {
  const _PromptView({required this.controller, required this.onGenerate});
  final TextEditingController controller;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: AppColors.green50, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_rounded, size: 32, color: AppColors.green500),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Опиши, что хочешь приготовить', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Например: "Хочу ужин до 600 ккал и минимум 40 г белка" — AI придумает рецепт, а реальные калории и БЖУ посчитаются по данным из базы продуктов',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: controller,
          maxLines: 3,
          minLines: 3,
          decoration: const InputDecoration(hintText: 'Хочу лёгкий ужин с курицей и овощами...'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s, style: Theme.of(context).textTheme.labelSmall),
                onPressed: () {
                  controller.text = s;
                  controller.selection = TextSelection.collapsed(offset: s.length);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => ElevatedButton.icon(
              onPressed: controller.text.trim().length >= 3 ? onGenerate : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Придумать рецепт'),
            ),
          ),
        ),
      ],
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text('AI придумывает рецепт…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.ink400),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(onPressed: onRetry, child: const Text('Попробовать снова')),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.recipe,
    required this.saving,
    required this.addingToDiary,
    required this.onResolveIngredient,
    required this.onSave,
    required this.onAddToDiary,
    required this.onRegenerate,
  });

  final GeneratedRecipe recipe;
  final bool saving;
  final bool addingToDiary;
  final void Function(int index) onResolveIngredient;
  final VoidCallback onSave;
  final VoidCallback onAddToDiary;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final busy = saving || addingToDiary;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            children: [
              Text(recipe.name, style: Theme.of(context).textTheme.headlineMedium),
              if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(recipe.description!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _MetaChip(icon: Icons.people_outline_rounded, label: '${_formatServings(recipe.servings)} порц.'),
                  if (recipe.cookingTimeMinutes != null) ...[
                    const SizedBox(width: 8),
                    _MetaChip(icon: Icons.timer_outlined, label: '${recipe.cookingTimeMinutes} мин'),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (recipe.constraints != null) _ConstraintsBanner(recipe: recipe),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('На порцию', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    _NutritionRow(nutrients: recipe.nutritionPerServing),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Ингредиенты', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < recipe.ingredients.length; i++) ...[
                _IngredientRow(ingredient: recipe.ingredients[i], onResolve: () => onResolveIngredient(i)),
                const SizedBox(height: 8),
              ],
              if (recipe.hasUnresolvedIngredients) ...[
                const SizedBox(height: 4),
                Text(
                  'Выбери продукт из базы для каждой позиции, чтобы сохранить рецепт или добавить в дневник',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Приготовление', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(recipe.instructions, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(onPressed: busy ? null : onRegenerate, child: const Text('Придумать другой рецепт')),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: recipe.hasUnresolvedIngredients || busy ? null : onSave,
                      child: saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Сохранить рецепт'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: recipe.hasUnresolvedIngredients || busy ? null : onAddToDiary,
                      child: addingToDiary
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('В дневник'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatServings(double servings) => servings == servings.roundToDouble() ? servings.toStringAsFixed(0) : servings.toString();
}

class _ConstraintsBanner extends StatelessWidget {
  const _ConstraintsBanner({required this.recipe});
  final GeneratedRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final ok = recipe.constraintsSatisfied;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ok ? AppColors.green50 : AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 18, color: ok ? AppColors.green600 : AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Уложились в заданные ограничения по КБЖУ' : 'Не совсем уложились в заданные ограничения по КБЖУ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (recipe.adjustmentNote != null) ...[
                  const SizedBox(height: 2),
                  Text(recipe.adjustmentNote!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
                ],
              ],
            ),
          ),
        ],
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
  const _IngredientRow({required this.ingredient, required this.onResolve});
  final GeneratedIngredient ingredient;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final quantityLabel = ingredient.quantity == ingredient.quantity.roundToDouble()
        ? ingredient.quantity.toStringAsFixed(0)
        : ingredient.quantity.toString();

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          FoodThumbnail(
            id: ingredient.matchedFoodId ?? ingredient.aiName,
            imageUrl: ingredient.matchedFoodImageUrl,
            emoji: ingredient.matchedFoodEmoji,
            size: 36,
            iconSize: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ingredient.matchedFoodName ?? ingredient.aiName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (!ingredient.isResolved)
            TextButton(onPressed: onResolve, child: const Text('Выбрать'))
          else ...[
            Text('$quantityLabel ${ingredient.unit.label}', style: Theme.of(context).textTheme.bodySmall),
            TextButton(onPressed: onResolve, child: const Text('Изменить')),
          ],
        ],
      ),
    );
  }
}

class _MealTypePickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Добавить в какой приём пищи?', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            for (final type in MealType.values) ...[
              AppCard(
                onTap: () => Navigator.of(context).pop(type),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Text(type.label, style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
