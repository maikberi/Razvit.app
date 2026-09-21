import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/exercise.dart';

/// Одна страница результатов каталога упражнений + метаданные пагинации.
class ExerciseSearchResult {
  const ExerciseSearchResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  const ExerciseSearchResult.empty()
      : items = const [],
        page = 1,
        perPage = 20,
        total = 0,
        totalPages = 1;

  final List<Exercise> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Клиент библиотеки упражнений backend RAZVIT (GET /exercises) — заменяет
/// прежний захардкоженный mockExercises (25 упражнений, почти без медиа)
/// настоящим каталогом с анимациями техники выполнения.
class ExerciseApiService {
  ExerciseApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ExerciseSearchResult> search({
    String? query,
    MuscleGroup? muscleGroup,
    ExerciseDifficulty? difficulty,
    int page = 1,
    int perPage = 20,
  }) async {
    final json = await _client.getJson('/api/v1/exercises', query: {
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (muscleGroup != null) 'muscleGroup': muscleGroup.name,
      if (difficulty != null) 'difficulty': difficulty.name,
      'page': '$page',
      'perPage': '$perPage',
    });
    return _parsePage(json);
  }

  Future<Exercise> getById(String id) async {
    final json = await _client.getJson('/api/v1/exercises/${Uri.encodeComponent(id)}');
    return Exercise.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<Exercise>> listFavorites() async {
    final json = await _client.getJson('/api/v1/exercises/favorites');
    final data = (json['data'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    return data.map(Exercise.fromJson).toList();
  }

  Future<void> setFavorite(String id, bool favorite) async {
    final path = '/api/v1/exercises/${Uri.encodeComponent(id)}/favorite';
    if (favorite) {
      await _client.postJson(path, const {});
    } else {
      await _client.delete(path);
    }
  }

  ExerciseSearchResult _parsePage(Map<String, dynamic> json) {
    final data = (json['data'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return ExerciseSearchResult(
      items: data.map(Exercise.fromJson).toList(),
      page: (meta['page'] as num?)?.toInt() ?? 1,
      perPage: (meta['perPage'] as num?)?.toInt() ?? data.length,
      total: (meta['total'] as num?)?.toInt() ?? data.length,
      totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

final exerciseApiServiceProvider = Provider<ExerciseApiService>((ref) => ExerciseApiService());
