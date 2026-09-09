import 'dart:html' as html;

import '../config/env.dart';

/// VK и Telegram Login здесь реализованы через редирект на страницу
/// провайдера и обратно (а не всплывающее окно/встроенный JS-виджет) —
/// проще и надёжнее для Flutter Web, не требует JS-интеропа с виджетами.
/// После возврата провайдер добавляет свои параметры к тому же адресу
/// (см. core/router/app_router.dart — маршруты /auth/vk-callback и
/// /auth/telegram-callback), их читает соответствующий callback-экран.
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

  static String vkRedirectUri() => '$_baseUrl#/auth/vk-callback';
  static String telegramReturnUrl() => '$_baseUrl#/auth/telegram-callback';

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
    html.window.location.href = uri.toString();
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
    html.window.location.href = uri.toString();
  }
}
