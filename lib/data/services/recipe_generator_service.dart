import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/recipe_generator.dart';

class RecipeGeneratorService {
  RecipeGeneratorService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<GeneratedRecipe> generate(String prompt) async {
    final json = await _client.postJson(
      '/api/v1/recipe-generator/generate',
      {'prompt': prompt},
      // AI придумывает рецепт, потом (иногда) повторно генерирует с обратной
      // связью, если не уложился в ограничения — дольше обычного запроса.
      timeout: const Duration(seconds: 45),
    );
    return GeneratedRecipe.fromJson(json['data'] as Map<String, dynamic>);
  }
}

final recipeGeneratorServiceProvider = Provider<RecipeGeneratorService>((ref) => RecipeGeneratorService());
