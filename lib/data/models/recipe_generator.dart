import 'recipe.dart';

/// Ограничения на КБЖУ одной порции, которые AI распознал в свободном тексте
/// запроса пользователя (например "до 600 ккал и минимум 40 г белка").
class RecipeGenerationConstraints {
  const RecipeGenerationConstraints({
    this.minCalories,
    this.maxCalories,
    this.minProtein,
    this.maxProtein,
    this.minFat,
    this.maxFat,
    this.minCarbohydrates,
    this.maxCarbohydrates,
  });

  final double? minCalories;
  final double? maxCalories;
  final double? minProtein;
  final double? maxProtein;
  final double? minFat;
  final double? maxFat;
  final double? minCarbohydrates;
  final double? maxCarbohydrates;

  factory RecipeGenerationConstraints.fromJson(Map<String, dynamic> json) => RecipeGenerationConstraints(
        minCalories: (json['minCalories'] as num?)?.toDouble(),
        maxCalories: (json['maxCalories'] as num?)?.toDouble(),
        minProtein: (json['minProtein'] as num?)?.toDouble(),
        maxProtein: (json['maxProtein'] as num?)?.toDouble(),
        minFat: (json['minFat'] as num?)?.toDouble(),
        maxFat: (json['maxFat'] as num?)?.toDouble(),
        minCarbohydrates: (json['minCarbohydrates'] as num?)?.toDouble(),
        maxCarbohydrates: (json['maxCarbohydrates'] as num?)?.toDouble(),
      );
}

/// Один ингредиент придуманного AI рецепта — уже сопоставленный (или нет)
/// с реальным продуктом из Food Database (см. FoodMatchingService на backend).
class GeneratedIngredient {
  const GeneratedIngredient({
    required this.aiName,
    required this.quantity,
    required this.unit,
    required this.grams,
    required this.matchedFoodId,
    required this.matchedFoodName,
    required this.matchedFoodImageUrl,
    required this.matchedFoodEmoji,
    required this.matchTier,
  });

  final String aiName;
  final double quantity;
  final RecipeIngredientUnit unit;
  final double grams;
  /// null — продукт не нашёлся в базе, нужно выбрать вручную, прежде чем
  /// можно будет сохранить рецепт или добавить его в дневник.
  final String? matchedFoodId;
  final String? matchedFoodName;
  final String? matchedFoodImageUrl;
  final String? matchedFoodEmoji;
  final String? matchTier;

  bool get isResolved => matchedFoodId != null;

  factory GeneratedIngredient.fromJson(Map<String, dynamic> json) => GeneratedIngredient(
        aiName: json['aiName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: RecipeIngredientUnitX.fromApi(json['unit'] as String),
        grams: (json['grams'] as num).toDouble(),
        matchedFoodId: json['matchedFoodId'] as String?,
        matchedFoodName: json['matchedFoodName'] as String?,
        matchedFoodImageUrl: json['matchedFoodImageUrl'] as String?,
        matchedFoodEmoji: json['matchedFoodEmoji'] as String?,
        matchTier: json['matchTier'] as String?,
      );

  GeneratedIngredient withManualMatch({
    required String foodId,
    required String foodName,
    required String? foodImageUrl,
    required String? foodEmoji,
  }) =>
      GeneratedIngredient(
        aiName: aiName,
        quantity: quantity,
        unit: unit,
        grams: grams,
        matchedFoodId: foodId,
        matchedFoodName: foodName,
        matchedFoodImageUrl: foodImageUrl,
        matchedFoodEmoji: foodEmoji,
        matchTier: 'exact',
      );
}

/// Рецепт, придуманный AI Recipe Generator: название/ингредиенты/инструкция
/// от AI, а КБЖУ — всегда от Food Database + Nutrition Engine на backend,
/// AI никогда не источник истины для калорий и БЖУ (см. recipeGenerator.service.ts).
class GeneratedRecipe {
  const GeneratedRecipe({
    required this.name,
    required this.description,
    required this.servings,
    required this.cookingTimeMinutes,
    required this.instructions,
    required this.ingredients,
    required this.nutritionTotal,
    required this.nutritionPerServing,
    required this.constraints,
    required this.constraintsSatisfied,
    required this.hasUnresolvedIngredients,
    required this.adjustmentNote,
  });

  final String name;
  final String? description;
  final double servings;
  final int? cookingTimeMinutes;
  final String instructions;
  final List<GeneratedIngredient> ingredients;
  final RecipeNutrients nutritionTotal;
  final RecipeNutrients nutritionPerServing;
  final RecipeGenerationConstraints? constraints;
  final bool constraintsSatisfied;
  final bool hasUnresolvedIngredients;
  final String? adjustmentNote;

  factory GeneratedRecipe.fromJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition'] as Map<String, dynamic>;
    return GeneratedRecipe(
      name: json['name'] as String,
      description: json['description'] as String?,
      servings: (json['servings'] as num).toDouble(),
      cookingTimeMinutes: (json['cookingTimeMinutes'] as num?)?.round(),
      instructions: json['instructions'] as String,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => GeneratedIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      nutritionTotal: RecipeNutrients.fromJson(nutrition['total'] as Map<String, dynamic>),
      nutritionPerServing: RecipeNutrients.fromJson(nutrition['perServing'] as Map<String, dynamic>),
      constraints: json['constraints'] == null ? null : RecipeGenerationConstraints.fromJson(json['constraints'] as Map<String, dynamic>),
      constraintsSatisfied: json['constraintsSatisfied'] as bool,
      hasUnresolvedIngredients: json['hasUnresolvedIngredients'] as bool,
      adjustmentNote: json['adjustmentNote'] as String?,
    );
  }

  GeneratedRecipe withIngredient(int index, GeneratedIngredient ingredient) {
    final updated = [...ingredients];
    updated[index] = ingredient;
    return GeneratedRecipe(
      name: name,
      description: description,
      servings: servings,
      cookingTimeMinutes: cookingTimeMinutes,
      instructions: instructions,
      ingredients: updated,
      nutritionTotal: nutritionTotal,
      nutritionPerServing: nutritionPerServing,
      constraints: constraints,
      constraintsSatisfied: constraintsSatisfied,
      hasUnresolvedIngredients: updated.any((i) => !i.isResolved),
      adjustmentNote: adjustmentNote,
    );
  }
}
