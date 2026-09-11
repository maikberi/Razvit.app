import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/recipe.dart';

class RecipeService {
  RecipeService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Recipe>> list({String? q, bool mine = false, bool favoriteOnly = false}) async {
    final json = await _client.getJson('/api/v1/recipes', query: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (mine) 'mine': 'true',
      if (favoriteOnly) 'favoriteOnly': 'true',
      'perPage': '100',
    });
    final data = (json['data'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(Recipe.fromJson).toList();
  }

  Future<Recipe> getById(String id) async {
    final json = await _client.getJson('/api/v1/recipes/${Uri.encodeComponent(id)}');
    return Recipe.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Recipe> create({
    required String name,
    String? description,
    String? imageUrl,
    required double servings,
    int? cookingTimeMinutes,
    required String instructions,
    required List<RecipeIngredientDraft> ingredients,
  }) async {
    final json = await _client.postJson('/api/v1/recipes', {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'servings': servings,
      'cookingTimeMinutes': cookingTimeMinutes,
      'instructions': instructions,
      'ingredients': ingredients.map((i) => i.toRequestJson()).toList(),
    });
    return Recipe.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<Recipe> update({
    required String id,
    required String name,
    String? description,
    String? imageUrl,
    required double servings,
    int? cookingTimeMinutes,
    required String instructions,
    required List<RecipeIngredientDraft> ingredients,
  }) async {
    final json = await _client.putJson('/api/v1/recipes/${Uri.encodeComponent(id)}', {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'servings': servings,
      'cookingTimeMinutes': cookingTimeMinutes,
      'instructions': instructions,
      'ingredients': ingredients.map((i) => i.toRequestJson()).toList(),
    });
    return Recipe.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _client.delete('/api/v1/recipes/${Uri.encodeComponent(id)}');

  Future<void> setFavorite(String id, bool favorite) => favorite
      ? _client.postJson('/api/v1/recipes/${Uri.encodeComponent(id)}/favorite', const {})
      : _client.delete('/api/v1/recipes/${Uri.encodeComponent(id)}/favorite');
}

final recipeServiceProvider = Provider<RecipeService>((ref) => RecipeService());

/// Список рецептов с фильтрами (поиск по имени, только избранное) —
/// перезапрашивается заново при смене фильтра или после мутации
/// (создание/редактирование/удаление/избранное), а не считается на
/// клиенте, чтобы список всегда совпадал с тем, что реально в базе.
class RecipeListNotifier extends StateNotifier<AsyncValue<List<Recipe>>> {
  RecipeListNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }

  final RecipeService _service;
  String _query = '';
  bool _favoritesOnly = false;

  bool get favoritesOnly => _favoritesOnly;
  String get query => _query;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final items = await _service.list(q: _query, favoriteOnly: _favoritesOnly);
      state = AsyncValue.data(items);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }

  Future<void> setQuery(String query) async {
    _query = query;
    await refresh();
  }

  Future<void> setFavoritesOnly(bool value) async {
    _favoritesOnly = value;
    await refresh();
  }

  Future<void> toggleFavorite(String id, bool favorite) async {
    await _service.setFavorite(id, favorite);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data([
        for (final r in current)
          if (r.id == id) r.copyWith(isFavorite: favorite) else r,
      ]);
    }
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.where((r) => r.id != id).toList());
    }
  }
}

final recipeListProvider = StateNotifierProvider<RecipeListNotifier, AsyncValue<List<Recipe>>>(
  (ref) => RecipeListNotifier(ref.watch(recipeServiceProvider)),
);

final recipeDetailProvider = FutureProvider.family<Recipe, String>(
  (ref, id) => ref.watch(recipeServiceProvider).getById(id),
);
