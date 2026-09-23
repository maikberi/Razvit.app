import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:razvit/core/network/api_client.dart';
import 'package:razvit/data/models/nutrition.dart';
import 'package:razvit/data/services/food_service.dart';
import 'package:razvit/features/nutrition/presentation/add_food_screen.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

FoodService _serviceWith(Future<http.Response> Function(http.Request) handler) {
  return FoodService(client: ApiClient(client: MockClient(handler), baseUrl: 'http://test.local'));
}

Widget _wrap(FoodService foodService) {
  return ProviderScope(
    overrides: [foodServiceProvider.overrideWithValue(foodService)],
    child: const MaterialApp(home: AddFoodScreen(mealId: 'meal-1', mealType: MealType.breakfast)),
  );
}

void main() {
  testWidgets('после debounce загружает и показывает найденный онлайн-продукт', (tester) async {
    final service = _serviceWith((req) async {
      return http.Response(
        '{"data":[{"id":"ext-1","name":"Уникальный тестовый продукт","caloriesPer100g":100,'
        '"proteinPer100g":1,"fatPer100g":1,"carbsPer100g":1,"source":"OFF"}],'
        '"meta":{"page":1,"perPage":20,"total":1,"totalPages":1}}',
        200,
        headers: _jsonHeaders,
      );
    });

    await tester.pumpWidget(_wrap(service));
    // До ввода запроса — ни спиннера, ни результата online-поиска.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'уникальный запрос');
    await tester.pump(const Duration(milliseconds: 500)); // debounce
    await tester.pumpAndSettle();

    expect(find.text('Уникальный тестовый продукт'), findsOneWidget);
  });

  testWidgets('показывает пустое состояние, если ничего не найдено ни локально, ни онлайн', (tester) async {
    final service = _serviceWith(
      (req) async => http.Response(
        '{"data":[],"meta":{"page":1,"perPage":20,"total":0,"totalPages":1}}',
        200,
        headers: _jsonHeaders,
      ),
    );

    await tester.pumpWidget(_wrap(service));
    await tester.enterText(find.byType(TextField).first, 'несуществующий продукт');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Продукт не найден'), findsOneWidget);
  });

  testWidgets('показывает ошибку сервера с кнопкой "Повторить", которая перезапускает запрос', (tester) async {
    var attempt = 0;
    final service = _serviceWith((req) async {
      attempt++;
      if (attempt == 1) {
        return http.Response(
          '{"error":{"code":"INTERNAL_ERROR","message":"Сервер недоступен, попробуй позже"}}',
          500,
          headers: _jsonHeaders,
        );
      }
      return http.Response(
        '{"data":[],"meta":{"page":1,"perPage":20,"total":0,"totalPages":1}}',
        200,
        headers: _jsonHeaders,
      );
    });

    await tester.pumpWidget(_wrap(service));
    await tester.enterText(find.byType(TextField).first, 'запрос с ошибкой');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Сервер недоступен, попробуй позже'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Сервер недоступен, попробуй позже'), findsNothing);
    expect(attempt, 2);
  });

  testWidgets('подгружает следующую страницу сама при докрутке до конца (infinite scroll)', (tester) async {
    final page1Items = List.generate(
      12,
      (i) => '{"id":"ext-p1-$i","name":"Продукт страницы один №$i","caloriesPer100g":90,'
          '"proteinPer100g":1,"fatPer100g":1,"carbsPer100g":1,"source":"OFF"}',
    ).join(',');

    final service = _serviceWith((req) async {
      final page = req.url.queryParameters['page'];
      if (page == '2') {
        return http.Response(
          '{"data":[{"id":"ext-2","name":"Второй продукт со страницы 2","caloriesPer100g":90,'
          '"proteinPer100g":1,"fatPer100g":1,"carbsPer100g":1,"source":"OFF"}],'
          '"meta":{"page":2,"perPage":12,"total":13,"totalPages":2}}',
          200,
          headers: _jsonHeaders,
        );
      }
      return http.Response(
        '{"data":[$page1Items],"meta":{"page":1,"perPage":12,"total":13,"totalPages":2}}',
        200,
        headers: _jsonHeaders,
      );
    });

    await tester.pumpWidget(_wrap(service));
    await tester.enterText(find.byType(TextField).first, 'много продуктов');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Продукт страницы один №0'), findsOneWidget);
    expect(find.text('Второй продукт со страницы 2'), findsNothing);
    // Без ручной кнопки — только докрутка вниз.
    expect(find.text('Показать ещё'), findsNothing);

    await tester.fling(find.byType(ListView), const Offset(0, -3000), 4000);
    await tester.pumpAndSettle();

    expect(find.text('Второй продукт со страницы 2'), findsOneWidget);
  });
}
