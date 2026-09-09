import '../config/env.dart';
import 'social_redirect_navigate_stub.dart'
    if (dart.library.html) 'social_redirect_navigate_web.dart' as platform;

/// VK и Telegram Login здесь реализованы через редирект на страницу
/// провайдера и обратно (а не всплывающее окно/встроенный JS-виджет) —
/// проще и надёжнее для Flutter Web, не требует JS-интеропа с виджетами.
///
/// redirect_uri/return_to указывают на КОРЕНЬ сайта без "#" — провайдеры
/// проверяют этот адрес как обычную ссылку (VK явно отклоняет адрес с
/// фрагментом: "Обязателен протокол https"), а сам сайт — статика без
/// серверного роутинга (GitHub Pages), так что путь глубже корня после
/// редиректа просто не откроется (404). Поэтому VK/Telegram дописывают
/// свои параметры (code/id/hash/...) как обычный query root-адреса, а
/// main.dart разбирает их ДО инициализации go_router (см.
/// vkCallbackInitialRoute) и стартует сразу на нужном экране.
abstract final class SocialRedirectGateway {
  static bool get isVkConfigured => Env.vkClientId.isNotEmpty;
  static bool get isTelegramConfigured => Env.telegramBotId.isNotEmpty;

  /// origin (схема+хост+порт, без пути) — Telegram сверяет его с доменом,
  /// привязанным к боту через /setdomain у @BotFather.
  static String get _origin => Uri.base.origin;

  /// Текущий адрес страницы без query/fragment — база для формирования
  /// redirect_uri/return_to, чтобы работало и на GitHub Pages (с подпутём
  /// /Razvit.app/), и локально.
  static String get _baseUrl => Uri.base.removeFragment().toString();

  static String vkRedirectUri() => _baseUrl;
  static String telegramReturnUrl() => _baseUrl;

  /// Вызывается из main.dart ДО создания GoRouter. Если текущий адрес —
  /// это возврат от VK (есть "code" после успешного входа или "error"
  /// после отказа), возвращает начальный маршрут для GoRouter с этими же
  /// параметрами; иначе null (обычный запуск приложения). Заодно стирает
  /// query из адресной строки, чтобы код не переиспользовался повторно
  /// при обновлении страницы.
  static String? vkCallbackInitialRoute() {
    final params = Uri.base.queryParameters;
    if (!params.containsKey('code') && !params.containsKey('error')) return null;
    platform.clearBootQuery();
    return Uri(path: '/auth/vk-callback', queryParameters: params).toString();
  }

  static void startVkLogin() {
    if (!isVkConfigured) {
      throw StateError('Вход через VK не настроен: не задан VK_CLIENT_ID при сборке.');
    }
    final uri = Uri.https('oauth.vk.com', '/authorize', {
      'client_id': Env.vkClientId,
      'display': 'page',
      'redirect_uri': vkRedirectUri(),
      'scope': 'email',
      'response_type': 'code',
      'v': '5.199',
    });
    platform.navigateTo(uri.toString());
  }

  static void startTelegramLogin() {
    if (!isTelegramConfigured) {
      throw StateError('Вход через Telegram не настроен: не задан TELEGRAM_BOT_ID при сборке.');
    }
    final uri = Uri.https('oauth.telegram.org', '/auth', {
      'bot_id': Env.telegramBotId,
      'origin': _origin,
      'embed': '0',
      'request_access': 'write',
      'return_to': telegramReturnUrl(),
    });
    platform.navigateTo(uri.toString());
  }
}
