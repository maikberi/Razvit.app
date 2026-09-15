/// Один продукт, распознанный AI на фото — уже сопоставленный (или нет)
/// с продуктом из Food Database. Нутриенты, если есть, посчитаны backend'ом
/// (Nutrition Engine) из реальных данных БД на [estimatedGrams] — AI сам
/// только называет продукт и оценивает вес, никогда не считает КБЖУ.
class RecognizedFoodItem {
  const RecognizedFoodItem({
    required this.aiName,
    required this.estimatedGrams,
    required this.confidence,
    required this.possibleAlternatives,
    required this.uncertainty,
    required this.matchedFoodId,
    required this.matchedFoodName,
    required this.matchedFoodImageUrl,
    required this.matchedFoodEmoji,
    required this.matchedBasisUnit,
    required this.matchTier,
    required this.matchScore,
    required this.needsConfirmation,
    required this.nutrition,
  });

  final String aiName;
  final double estimatedGrams;
  final double confidence;
  final List<String> possibleAlternatives;
  final String? uncertainty;
  final String? matchedFoodId;
  final String? matchedFoodName;
  final String? matchedFoodImageUrl;
  final String? matchedFoodEmoji;
  final String? matchedBasisUnit;
  /// 'exact' | 'alias' | 'fuzzy' | 'category' | null — на какой ступени
  /// backend-пайплайна нашлось совпадение (см. FoodMatchingService).
  final String? matchTier;
  final double? matchScore;
  /// true — backend решил, что это не однозначный результат (слабая ступень
  /// совпадения или AI сам не очень уверен) — карточка должна явно
  /// попросить пользователя проверить/подтвердить, а не тихо считать её готовой.
  final bool needsConfirmation;
  final RecognizedNutrition? nutrition;

  bool get isMatched => matchedFoodId != null;

  factory RecognizedFoodItem.fromJson(Map<String, dynamic> json) => RecognizedFoodItem(
        aiName: json['aiName'] as String,
        estimatedGrams: (json['estimatedGrams'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        possibleAlternatives: (json['possibleAlternatives'] as List<dynamic>? ?? const []).cast<String>(),
        uncertainty: json['uncertainty'] as String?,
        matchedFoodId: json['matchedFoodId'] as String?,
        matchedFoodName: json['matchedFoodName'] as String?,
        matchedFoodImageUrl: json['matchedFoodImageUrl'] as String?,
        matchedFoodEmoji: json['matchedFoodEmoji'] as String?,
        matchedBasisUnit: json['matchedBasisUnit'] as String?,
        matchTier: json['matchTier'] as String?,
        matchScore: (json['matchScore'] as num?)?.toDouble(),
        needsConfirmation: json['needsConfirmation'] as bool? ?? true,
        nutrition: json['nutrition'] == null ? null : RecognizedNutrition.fromJson(json['nutrition'] as Map<String, dynamic>),
      );

  /// Карточка после того, как пользователь сам выбрал продукт из базы
  /// (для изначально несопоставленного элемента) — заменяет aiName-заглушку
  /// на настоящий продукт, оставляя ту же оценку веса.
  RecognizedFoodItem withManualMatch({
    required String foodId,
    required String foodName,
    required String? foodImageUrl,
    required String? foodEmoji,
    required String basisUnit,
  }) =>
      RecognizedFoodItem(
        aiName: aiName,
        estimatedGrams: estimatedGrams,
        confidence: confidence,
        possibleAlternatives: possibleAlternatives,
        uncertainty: uncertainty,
        matchedFoodId: foodId,
        matchedFoodName: foodName,
        matchedFoodImageUrl: foodImageUrl,
        matchedFoodEmoji: foodEmoji,
        matchedBasisUnit: basisUnit,
        // Пользователь сам выбрал продукт из базы — сомневаться больше не в чем.
        matchTier: 'exact',
        matchScore: 1,
        needsConfirmation: false,
        nutrition: nutrition,
      );

  RecognizedFoodItem withNutrition(RecognizedNutrition? nutrition) => RecognizedFoodItem(
        aiName: aiName,
        estimatedGrams: estimatedGrams,
        confidence: confidence,
        possibleAlternatives: possibleAlternatives,
        uncertainty: uncertainty,
        matchedFoodId: matchedFoodId,
        matchedFoodName: matchedFoodName,
        matchedFoodImageUrl: matchedFoodImageUrl,
        matchedFoodEmoji: matchedFoodEmoji,
        matchedBasisUnit: matchedBasisUnit,
        matchTier: matchTier,
        matchScore: matchScore,
        needsConfirmation: needsConfirmation,
        nutrition: nutrition,
      );

  RecognizedFoodItem withGrams(double grams) => RecognizedFoodItem(
        aiName: aiName,
        estimatedGrams: grams,
        confidence: confidence,
        possibleAlternatives: possibleAlternatives,
        uncertainty: uncertainty,
        matchedFoodId: matchedFoodId,
        matchedFoodName: matchedFoodName,
        matchedFoodImageUrl: matchedFoodImageUrl,
        matchedFoodEmoji: matchedFoodEmoji,
        matchedBasisUnit: matchedBasisUnit,
        matchTier: matchTier,
        matchScore: matchScore,
        needsConfirmation: needsConfirmation,
        nutrition: nutrition,
      );
}

class RecognizedNutrition {
  const RecognizedNutrition({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
  });

  final int calories;
  final double protein;
  final double fat;
  final double carbohydrates;

  factory RecognizedNutrition.fromJson(Map<String, dynamic> json) => RecognizedNutrition(
        calories: (json['calories'] as num).round(),
        protein: (json['protein'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        carbohydrates: (json['carbohydrates'] as num).toDouble(),
      );
}

class FoodRecognitionResult {
  const FoodRecognitionResult({required this.items, required this.notes});

  final List<RecognizedFoodItem> items;
  final String? notes;

  factory FoodRecognitionResult.fromJson(Map<String, dynamic> json) => FoodRecognitionResult(
        items: (json['items'] as List<dynamic>).map((e) => RecognizedFoodItem.fromJson(e as Map<String, dynamic>)).toList(),
        notes: json['notes'] as String?,
      );
}
