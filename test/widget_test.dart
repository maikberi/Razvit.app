import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:razvit/app.dart';

void main() {
  testWidgets('Приложение запускается и показывает экран приветствия', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RazvitApp()));
    await tester.pump();

    expect(find.textContaining('RAZVIT'), findsWidgets);
  });
}
