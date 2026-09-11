import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/models/recipe.dart';
import '../../../data/services/recipe_service.dart';
import 'food_ui.dart';
import 'recipe_ingredient_picker_screen.dart';

/// Создание и редактирование рецепта одной формой — если [recipeId] задан,
/// подгружает существующий рецепт и предзаполняет поля; иначе пустая форма.
class RecipeFormScreen extends ConsumerWidget {
  const RecipeFormScreen({super.key, this.recipeId});

  final String? recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = recipeId;
    if (id == null) return const _RecipeFormBody(initial: null);

    final async = ref.watch(recipeDetailProvider(id));
    return async.when(
      loading: () => Scaffold(appBar: AppBar(title: const Text('Рецепт'), leading: const BackButton()), body: const LoadingView()),
      error: (err, st) => Scaffold(
        appBar: AppBar(title: const Text('Рецепт'), leading: const BackButton()),
        body: ErrorView(
          message: err is ApiException ? err.message : 'Не удалось загрузить рецепт',
          onRetry: () => ref.invalidate(recipeDetailProvider(id)),
        ),
      ),
      data: (recipe) => _RecipeFormBody(initial: recipe),
    );
  }
}

/// Мутируемый черновик ингредиента для UI формы — по нему же строится
/// запрос на сохранение (только foodId/quantity/unit, остальное для показа).
class _DraftIngredient {
  _DraftIngredient({
    required this.foodId,
    required this.foodName,
    required this.foodImageUrl,
    required this.foodEmoji,
    required this.quantity,
    required this.unit,
  });

  factory _DraftIngredient.fromFood(FoodItem food) => _DraftIngredient(
        foodId: food.id,
        foodName: food.name,
        foodImageUrl: food.imageUrl,
        foodEmoji: food.emoji,
        quantity: food.defaultGrams.toDouble(),
        unit: RecipeIngredientUnit.g,
      );

  factory _DraftIngredient.fromExisting(RecipeIngredient ing) => _DraftIngredient(
        foodId: ing.foodId,
        foodName: ing.foodName,
        foodImageUrl: ing.foodImageUrl,
        foodEmoji: ing.foodEmoji,
        quantity: ing.quantity,
        unit: ing.unit,
      );

  final String foodId;
  final String foodName;
  final String? foodImageUrl;
  final String? foodEmoji;
  double quantity;
  RecipeIngredientUnit unit;
}

class _RecipeFormBody extends ConsumerStatefulWidget {
  const _RecipeFormBody({required this.initial});
  final Recipe? initial;

  @override
  ConsumerState<_RecipeFormBody> createState() => _RecipeFormBodyState();
}

class _RecipeFormBodyState extends ConsumerState<_RecipeFormBody> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late final _imageUrl = TextEditingController(text: widget.initial?.imageUrl ?? '');
  late final _servings = TextEditingController(text: (widget.initial?.servings ?? 1).toStringAsFixed(0));
  late final _cookingTime = TextEditingController(text: widget.initial?.cookingTimeMinutes?.toString() ?? '');
  late final _instructions = TextEditingController(text: widget.initial?.instructions ?? '');
  late final List<_DraftIngredient> _ingredients =
      (widget.initial?.ingredients ?? const []).map(_DraftIngredient.fromExisting).toList();

  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _imageUrl.dispose();
    _servings.dispose();
    _cookingTime.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final food = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(builder: (_) => const RecipeIngredientPickerScreen()),
    );
    if (food == null) return;
    setState(() => _ingredients.add(_DraftIngredient.fromFood(food)));
  }

  void _removeIngredient(int index) => setState(() => _ingredients.removeAt(index));

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final instructions = _instructions.text.trim();
    final servings = double.tryParse(_servings.text.trim().replaceAll(',', '.'));

    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Введите название рецепта'), backgroundColor: AppColors.error));
      return;
    }
    if (servings == null || servings <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Укажите корректное количество порций'), backgroundColor: AppColors.error));
      return;
    }
    if (instructions.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Опишите шаги приготовления'), backgroundColor: AppColors.error));
      return;
    }
    if (_ingredients.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Добавьте хотя бы один ингредиент'), backgroundColor: AppColors.error));
      return;
    }

    final cookingTime = int.tryParse(_cookingTime.text.trim());
    final drafts = _ingredients
        .map((i) => RecipeIngredientDraft(foodId: i.foodId, quantity: i.quantity, unit: i.unit))
        .toList();

    setState(() => _saving = true);
    try {
      final service = ref.read(recipeServiceProvider);
      final Recipe saved;
      if (_isEdit) {
        saved = await service.update(
          id: widget.initial!.id,
          name: name,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
          servings: servings,
          cookingTimeMinutes: cookingTime,
          instructions: instructions,
          ingredients: drafts,
        );
        ref.invalidate(recipeDetailProvider(widget.initial!.id));
      } else {
        saved = await service.create(
          name: name,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
          servings: servings,
          cookingTimeMinutes: cookingTime,
          instructions: instructions,
          ingredients: drafts,
        );
      }
      await ref.read(recipeListProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/recipes/${saved.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактировать рецепт' : 'Новый рецепт'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Название')),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Описание (необязательно)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _imageUrl,
              decoration: const InputDecoration(labelText: 'Ссылка на фото (необязательно)'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _servings,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Порций'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _cookingTime,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Время, мин (необязательно)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _instructions,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Шаги приготовления', alignLabelWithHint: true),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ингредиенты', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(onPressed: _addIngredient, icon: const Icon(Icons.add_rounded), label: const Text('Добавить')),
              ],
            ),
            if (_ingredients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('Пока пусто — добавьте хотя бы один ингредиент', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
              )
            else
              for (var i = 0; i < _ingredients.length; i++) ...[
                _IngredientFormRow(
                  ingredient: _ingredients[i],
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeIngredient(i),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isEdit ? 'Сохранить изменения' : 'Создать рецепт'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientFormRow extends StatelessWidget {
  const _IngredientFormRow({required this.ingredient, required this.onChanged, required this.onRemove});
  final _DraftIngredient ingredient;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          FoodThumbnail(id: ingredient.foodId, imageUrl: ingredient.foodImageUrl, emoji: ingredient.foodEmoji, size: 36, iconSize: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(ingredient.foodName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextFormField(
              initialValue: ingredient.quantity == ingredient.quantity.roundToDouble()
                  ? ingredient.quantity.toStringAsFixed(0)
                  : ingredient.quantity.toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
              onChanged: (v) {
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed != null && parsed > 0) {
                  ingredient.quantity = parsed;
                  onChanged();
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          DropdownButton<RecipeIngredientUnit>(
            value: ingredient.unit,
            underline: const SizedBox.shrink(),
            items: [
              for (final unit in RecipeIngredientUnit.values) DropdownMenuItem(value: unit, child: Text(unit.label)),
            ],
            onChanged: (unit) {
              if (unit == null) return;
              ingredient.unit = unit;
              onChanged();
            },
          ),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded, color: AppColors.ink400), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}
