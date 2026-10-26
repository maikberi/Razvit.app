/// Нутриенты рецепта — то же, что NutrientProfile на backend
/// (NutritionCalculationService.forRecipe): считаются на лету из
/// ингредиентов, никогда не задаются руками.
class RecipeNutrients {
  const RecipeNutrients({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.fiber,
    required this.sugar,
    required this.sodium,
  });

  final int calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final double fiber;
  final double? sugar;
  final double? sodium;

  factory RecipeNutrients.fromJson(Map<String, dynamic> json) => RecipeNutrients(
        calories: (json['calories'] as num).round(),
        protein: (json['protein'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        carbohydrates: (json['carbohydrates'] as num).toDouble(),
        fiber: (json['fiber'] as num).toDouble(),
        sugar: (json['sugar'] as num?)?.toDouble(),
        sodium: (json['sodium'] as num?)?.toDouble(),
      );
}

enum RecipeIngredientUnit { g, ml, pcs }

extension RecipeIngredientUnitX on RecipeIngredientUnit {
  String get apiValue => switch (this) {
        RecipeIngredientUnit.g => 'g',
        RecipeIngredientUnit.ml => 'ml',
        RecipeIngredientUnit.pcs => 'pcs',
      };

  String get label => switch (this) {
        RecipeIngredientUnit.g => 'г',
        RecipeIngredientUnit.ml => 'мл',
        RecipeIngredientUnit.pcs => 'шт',
      };

  static RecipeIngredientUnit fromApi(String raw) => switch (raw) {
        'ml' => RecipeIngredientUnit.ml,
        'pcs' => RecipeIngredientUnit.pcs,
        _ => RecipeIngredientUnit.g,
      };
}

/// Ингредиент рецепта — продукт + количество. [foodName]/[foodImageUrl]/
/// [foodEmoji]/[grams] приходят от backend уже "обогащённые" (как в Meal
/// Diary), чтобы не делать второй запрос за деталями продукта.
class RecipeIngredient {
  const RecipeIngredient({
    required this.foodId,
    required this.foodName,
    required this.foodImageUrl,
    required this.foodEmoji,
    required this.quantity,
    required this.unit,
    required this.grams,
  });

  final String foodId;
  final String foodName;
  final String? foodImageUrl;
  final String? foodEmoji;
  final double quantity;
  final RecipeIngredientUnit unit;
  final double grams;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
        foodId: json['foodId'] as String,
        foodName: json['foodName'] as String,
        foodImageUrl: json['foodImageUrl'] as String?,
        foodEmoji: json['foodEmoji'] as String?,
        quantity: (json['quantity'] as num).toDouble(),
        unit: RecipeIngredientUnitX.fromApi(json['unit'] as String),
        grams: (json['grams'] as num).toDouble(),
      );
}

/// То, что реально нужно отправить на create/update — backend сам
/// подтягивает имя/фото/граммы продукта и считает нутриенты, отправлять
/// их с клиента незачем.
class RecipeIngredientDraft {
  const RecipeIngredientDraft({required this.foodId, required this.quantity, required this.unit});

  final String foodId;
  final double quantity;
  final RecipeIngredientUnit unit;

  Map<String, dynamic> toRequestJson() => {
        'foodId': foodId,
        'quantity': quantity,
        'unit': unit.apiValue,
      };
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.servings,
    required this.cookingTimeMinutes,
    required this.instructions,
    required this.ingredients,
    required this.nutritionTotal,
    required this.nutritionPerServing,
    required this.isFavorite,
    required this.isOwner,
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double servings;
  final int? cookingTimeMinutes;
  final String instructions;
  final List<RecipeIngredient> ingredients;
  final RecipeNutrients nutritionTotal;
  final RecipeNutrients nutritionPerServing;
  final bool isFavorite;
  final bool isOwner;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition'] as Map<String, dynamic>;
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      servings: (json['servings'] as num).toDouble(),
      cookingTimeMinutes: (json['cookingTimeMinutes'] as num?)?.round(),
      instructions: json['instructions'] as String,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      nutritionTotal: RecipeNutrients.fromJson(nutrition['total'] as Map<String, dynamic>),
      nutritionPerServing: RecipeNutrients.fromJson(nutrition['perServing'] as Map<String, dynamic>),
      isFavorite: json['isFavorite'] as bool,
      isOwner: json['isOwner'] as bool,
    );
  }

  Recipe copyWith({bool? isFavorite}) => Recipe(
        id: id,
        name: name,
        description: description,
        imageUrl: imageUrl,
        servings: servings,
        cookingTimeMinutes: cookingTimeMinutes,
        instructions: instructions,
        ingredients: ingredients,
        nutritionTotal: nutritionTotal,
        nutritionPerServing: nutritionPerServing,
        isFavorite: isFavorite ?? this.isFavorite,
        isOwner: isOwner,
      );
}
