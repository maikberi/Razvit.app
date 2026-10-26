import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:razvit/core/network/api_client.dart';
import 'package:razvit/data/services/exercise_api_service.dart';
import 'package:razvit/features/workouts/presentation/tabs/catalog_tab.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

ExerciseApiService _serviceWith(Future<http.Response> Function(http.Request) handler) {
  return ExerciseApiService(client: ApiClient(client: MockClient(handler), baseUrl: 'http://test.local'));
}

Widget _wrap(ExerciseApiService service) {
  return ProviderScope(
    overrides: [exerciseApiServiceProvider.overrideWithValue(service)],
    child: const MaterialApp(home: Scaffold(body: CatalogTab())),
  );
}

String _exerciseJson(String id, String name, {String primaryMuscle = 'chest'}) =>
    '{"id":"$id","slug":"$id","name":"$name","primaryMuscle":"$primaryMuscle","secondaryMuscles":[],'
    '"equipment":"Штанга","difficulty":"intermediate","instructions":[],'
    '"gifUrl":"https://example.com/$id.gif","thumbUrl":"https://example.com/$id.thumb.webp","isFavorite":false}';

// pumpAndSettle зависает: строки списка тянут превью через
// CachedNetworkImage (ExerciseThumb), а его менеджер кэша в тестовом
// окружении (HttpClient всегда отвечает 400) планирует кадры бесконечно.
// Ограниченная серия pump() вместо pumpAndSettle — тот же эффект
// "дождаться ответа мок-сервиса и перерисовки", без зависания на картинках.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('загружает и показывает упражнения из backend при открытии', (tester) async {
    final service = _serviceWith(
      (req) async => http.Response(
        '{"data":[${_exerciseJson('bp', 'Жим штанги лёжа')}],'
        '"meta":{"page":1,"perPage":20,"total":1,"totalPages":1}}',
        200,
        headers: _jsonHeaders,
      ),
    );

    await tester.pumpWidget(_wrap(service));
    await _settle(tester);

    expect(find.text('Жим штанги лёжа'), findsOneWidget);
  });

  testWidgets('фильтр по группе мышц перезапускает поиск', (tester) async {
    String? lastMuscleGroup;
    final service = _serviceWith((req) async {
      lastMuscleGroup = req.url.queryParameters['muscleGroup'];
      return http.Response(
        '{"data":[],"meta":{"page":1,"perPage":20,"total":0,"totalPages":1}}',
        200,
        headers: _jsonHeaders,
      );
    });

    await tester.pumpWidget(_wrap(service));
    await _settle(tester);
    expect(lastMuscleGroup, isNull);

    await tester.tap(find.text('Ноги'));
    await _settle(tester);

    expect(lastMuscleGroup, 'legs');
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
        '{"data":[${_exerciseJson('bp', 'Жим штанги лёжа')}],'
        '"meta":{"page":1,"perPage":20,"total":1,"totalPages":1}}',
        200,
        headers: _jsonHeaders,
      );
    });

    await tester.pumpWidget(_wrap(service));
    await _settle(tester);

    expect(find.text('Не удалось загрузить упражнения'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await _settle(tester);

    expect(find.text('Жим штанги лёжа'), findsOneWidget);
    expect(attempt, 2);
  });

  testWidgets('пустой результат показывает EmptyState', (tester) async {
    final service = _serviceWith(
      (req) async => http.Response(
        '{"data":[],"meta":{"page":1,"perPage":20,"total":0,"totalPages":1}}',
        200,
        headers: _jsonHeaders,
      ),
    );

    await tester.pumpWidget(_wrap(service));
    await _settle(tester);

    expect(find.text('Ничего не найдено'), findsOneWidget);
  });
}
