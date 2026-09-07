import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/nutrition.dart';

/// Одна страница результатов поиска продуктов + метаданные пагинации.
class FoodSearchResult {
  const FoodSearchResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  const FoodSearchResult.empty()
      : items = const [],
        page = 1,
        perPage = 20,
        total = 0,
        totalPages = 1;

  final List<FoodItem> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Клиент Food Database backend RAZVIT — поиск, штрихкод, получение
/// продукта по id. Заменяет собой прежний прямой вызов Open Food Facts
/// с клиента (см. `git log` — файл `open_food_facts_service.dart`,
/// удалён: та же логика теперь на backend, backend/src/integrations).
class FoodService {
  FoodService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  static const int minQueryLength = 2;

  Future<FoodSearchResult> search(String query, {int page = 1, int perPage = 20}) async {
    final trimmed = query.trim();
    if (trimmed.length < minQueryLength) return const FoodSearchResult.empty();

    final json = await _client.getJson('/api/v1/foods', query: {
      'q': trimmed,
      'page': '$page',
      'perPage': '$perPage',
    });
    return _parsePage(json);
  }

  Future<FoodItem?> lookupBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;
    try {
      final json = await _client.getJson('/api/v1/foods/barcode/${Uri.encodeComponent(trimmed)}');
      return FoodItem.fromJson(json['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<FoodItem> getById(String id) async {
    final json = await _client.getJson('/api/v1/foods/${Uri.encodeComponent(id)}');
    return FoodItem.fromJson(json['data'] as Map<String, dynamic>);
  }

  FoodSearchResult _parsePage(Map<String, dynamic> json) {
    final data = (json['data'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return FoodSearchResult(
      items: data.map(FoodItem.fromJson).toList(),
      page: (meta['page'] as num?)?.toInt() ?? 1,
      perPage: (meta['perPage'] as num?)?.toInt() ?? data.length,
      total: (meta['total'] as num?)?.toInt() ?? data.length,
      totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

final foodServiceProvider = Provider<FoodService>((ref) => FoodService());
