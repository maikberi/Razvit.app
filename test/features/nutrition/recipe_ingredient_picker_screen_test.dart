import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:razvit/core/network/api_client.dart';
import 'package:razvit/data/services/food_service.dart';
import 'package:razvit/features/nutrition/presentation/recipe_ingredient_picker_screen.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

FoodService _serviceWith(Future<http.Response> Function(http.Request) handler) {
  return FoodService(client: ApiClient(client: MockClient(handler), baseUrl: 'http://test.local'));
}

Widget _wrap(FoodService foodService) {
  return ProviderScope(
    overrides: [foodServiceProvider.overrideWithValue(foodService)],
    child: const MaterialApp(home: RecipeIngredientPickerScreen()),
  );
}

void main() {
  testWidgets('подгружает следующую страницу при докрутке — раньше поиск молча обрезался на первых 20', (tester) async {
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

    await tester.fling(find.byType(ListView), const Offset(0, -3000), 4000);
    await tester.pumpAndSettle();

    expect(find.text('Второй продукт со страницы 2'), findsOneWidget);
  });

  testWidgets('ошибку сервера можно повторить кнопкой "Повторить"', (tester) async {
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

    expect(find.text('Не удалось найти'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось найти'), findsNothing);
    expect(attempt, 2);
  });

  testWidgets('нажатие на продукт возвращает его вызвавшему экрану', (tester) async {
    final service = _serviceWith(
      (req) async => http.Response(
        '{"data":[{"id":"ext-1","name":"Куриная грудка","caloriesPer100g":165,'
        '"proteinPer100g":31,"fatPer100g":3.6,"carbsPer100g":0,"source":"RAZVIT"}],'
        '"meta":{"page":1,"perPage":20,"total":1,"totalPages":1}}',
        200,
        headers: _jsonHeaders,
      ),
    );

    String? poppedFoodName;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [foodServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final food = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecipeIngredientPickerScreen()),
                );
                poppedFoodName = food?.name;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'курица');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Куриная грудка'));
    await tester.pumpAndSettle();

    expect(poppedFoodName, 'Куриная грудка');
  });
}
