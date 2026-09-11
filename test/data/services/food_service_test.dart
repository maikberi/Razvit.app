import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:razvit/core/network/api_client.dart';
import 'package:razvit/data/models/nutrition.dart';
import 'package:razvit/data/services/food_service.dart';

FoodService buildService(Future<http.Response> Function(http.Request) handler) {
  final mockClient = MockClient(handler);
  return FoodService(client: ApiClient(client: mockClient, baseUrl: 'http://test.local'));
}

/// http.Response по умолчанию кодирует тело как latin1 — с кириллицей в
/// теле это падает с "Contains invalid characters". Явно указываем utf-8,
/// как и делает настоящий backend (Content-Type: application/json; charset=utf-8).
http.Response jsonResponse(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('FoodService.search', () {
    test('не делает запрос, если запрос короче минимальной длины', () async {
      var called = false;
      final service = buildService((req) async {
        called = true;
        return jsonResponse({}, 200);
      });

      final result = await service.search('a');

      expect(called, isFalse);
      expect(result.items, isEmpty);
    });

    test('парсит успешный ответ с данными и пагинацией', () async {
      final service = buildService((req) async {
        expect(req.url.path, '/api/v1/foods');
        expect(req.url.queryParameters['q'], 'греча');
        return jsonResponse({
          'data': [
            {
              'id': 'abc-1',
              'name': 'Гречка',
              'caloriesPer100g': 110,
              'proteinPer100g': 4.2,
              'fatPer100g': 1.1,
              'carbsPer100g': 21.3,
              'source': 'RAZVIT',
            },
          ],
          'meta': {'page': 1, 'perPage': 20, 'total': 1, 'totalPages': 1},
        }, 200);
      });

      final result = await service.search('греча');

      expect(result.items, hasLength(1));
      expect(result.items.first.name, 'Гречка');
      expect(result.items.first.source, FoodSource.razvit);
      expect(result.total, 1);
      expect(result.hasMore, isFalse);
    });

    test('пробрасывает ApiException при ошибке сервера', () async {
      final service = buildService((req) async {
        return jsonResponse({
          'error': {'code': 'INTERNAL_ERROR', 'message': 'Упс'},
        }, 500);
      });

      expect(() => service.search('греча'), throwsA(isA<ApiException>()));
    });

    test('пробрасывает ApiException при сетевой ошибке (isNetworkError=true)', () async {
      final service = buildService((req) async {
        throw const SocketExceptionLike();
      });

      try {
        await service.search('греча');
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.isNetworkError, isTrue);
      }
    });

    test('page/perPage передаются в запрос', () async {
      final service = buildService((req) async {
        expect(req.url.queryParameters['page'], '2');
        expect(req.url.queryParameters['perPage'], '10');
        return jsonResponse({
          'data': [],
          'meta': {'page': 2, 'perPage': 10, 'total': 15, 'totalPages': 2},
        }, 200);
      });

      final result = await service.search('овсянка', page: 2, perPage: 10);
      expect(result.page, 2);
      expect(result.hasMore, isFalse);
    });
  });

  group('FoodService.lookupBarcode', () {
    test('возвращает продукт при найденном штрихкоде', () async {
      final service = buildService((req) async {
        expect(req.url.path, '/api/v1/foods/barcode/4600000000001');
        return jsonResponse({
          'data': {
            'id': 'x',
            'name': 'Молоко',
            'caloriesPer100g': 60,
            'proteinPer100g': 3,
            'fatPer100g': 3.2,
            'carbsPer100g': 4.7,
            'source': 'OFF',
            'barcode': '4600000000001',
          },
        }, 200);
      });

      final food = await service.lookupBarcode('4600000000001');
      expect(food, isNotNull);
      expect(food!.barcode, '4600000000001');
      expect(food.source, FoodSource.off);
    });

    test('возвращает null (не бросает исключение), если продукт не найден — 404', () async {
      final service = buildService((req) async {
        return jsonResponse({
          'error': {'code': 'FOOD_NOT_FOUND', 'message': 'Не найден'},
        }, 404);
      });

      final food = await service.lookupBarcode('0000000000000');
      expect(food, isNull);
    });

    test('пробрасывает ApiException для не-404 ошибок', () async {
      final service = buildService((req) async {
        return jsonResponse({
          'error': {'code': 'INTERNAL_ERROR', 'message': 'Упс'},
        }, 500);
      });

      expect(() => service.lookupBarcode('123'), throwsA(isA<ApiException>()));
    });
  });
}

/// Имитация сетевой ошибки без зависимости от dart:io (доступен на web).
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
