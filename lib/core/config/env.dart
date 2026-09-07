/// Единая точка чтения конфигурации окружения во Flutter.
/// Значения передаются на этапе сборки через --dart-define, например:
///   flutter run --dart-define=API_BASE_URL=https://api.razvit.app
/// Никаких ключей/секретов здесь быть не должно — backend не пускает
/// Flutter напрямую к внешним API (Open Food Facts/USDA), только через себя.
abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
