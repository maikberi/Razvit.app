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

  /// OAuth Client ID веб-приложения Google (не секрет — этот id специально
  /// предназначен для встраивания в клиентский код, см. console.cloud.google.com).
  /// Пустая строка означает "вход через Google не настроен" — соответствующая
  /// кнопка тогда просто не должна пытаться его использовать.
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
}
