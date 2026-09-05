import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/nutrition.dart';

/// Поиск продуктов через открытую базу Open Food Facts
/// (world.openfoodfacts.org) — бесплатный API без ключа, миллионы товаров
/// со штрихкодами, включая российские бренды. Используется как источник
/// базы продуктов вдобавок к локальному каталогу: если запрос сети не
/// удался (нет интернета/оффлайн), просто возвращаем пустой список —
/// экран поиска продолжает работать по локальной базе.
abstract final class OpenFoodFactsService {
  static const _searchUrl = 'https://world.openfoodfacts.org/cgi/search.pl';
  static const _productUrl = 'https://world.openfoodfacts.org/api/v0/product';

  static Future<List<FoodItem>> search(String query) async {
    if (query.trim().length < 3) return [];
    try {
      final uri = Uri.parse(_searchUrl).replace(queryParameters: {
        'search_terms': query,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '15',
        'fields': 'code,product_name,product_name_ru,brands,nutriments',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final products = (data['products'] as List?) ?? [];
      return products.map(_toFoodItem).whereType<FoodItem>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<FoodItem?> lookupBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    try {
      final uri = Uri.parse('$_productUrl/$code.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;
      return _toFoodItem(data['product'] as Map<String, dynamic>, id: 'off_$code');
    } catch (_) {
      return null;
    }
  }

  static FoodItem? _toFoodItem(dynamic raw, {String? id}) {
    if (raw is! Map<String, dynamic>) return null;
    final name = (raw['product_name_ru'] as String?)?.trim().isNotEmpty == true
        ? raw['product_name_ru'] as String
        : (raw['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final nutriments = raw['nutriments'] as Map<String, dynamic>?;
    if (nutriments == null) return null;
    final calories = _asDouble(nutriments['energy-kcal_100g']);
    if (calories == null) return null;

    return FoodItem(
      id: id ?? 'off_${raw['code'] ?? name.hashCode}',
      name: name,
      caloriesPer100g: calories.round(),
      proteinPer100g: _asDouble(nutriments['proteins_100g']) ?? 0,
      fatPer100g: _asDouble(nutriments['fat_100g']) ?? 0,
      carbsPer100g: _asDouble(nutriments['carbohydrates_100g']) ?? 0,
    );
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
