import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../config/env.dart';
import 'social_redirect_navigate_stub.dart'
    if (dart.library.html) 'social_redirect_navigate_web.dart' as platform;

/// VK ID (id.vk.ru) — текущий протокол авторизации VK, OAuth 2.1 + PKCE
/// (пришёл на смену классическому oauth.vk.com, который отклоняет запросы
/// от приложений, созданных через новую панель id.vk.com). Наше
/// приложение "конфиденциальное" (есть свой backend), поэтому по схеме
/// VK ID для Web без SDK: фронт генерирует PKCE-пару и state, уходит на
/// id.vk.ru/authorize, а после возврата передаёт code/device_id/state и
/// сохранённый code_verifier на backend — он и обменивает их на токен.
/// См. VkCallbackScreen и backend/src/modules/auth/vk.verifier.ts.
///
/// redirect_uri указывает на КОРЕНЬ сайта без "#" — VK проверяет его как
/// обычную ссылку (и отклоняет с "Security Error"/"Обязателен протокол
/// https" адреса с фрагментом), а сам сайт — статика без серверного
/// роутинга (GitHub Pages), так что путь глубже корня после редиректа
/// просто не откроется (404). Поэтому VK дописывает code/device_id/state
/// как обычный query root-адреса, а main.dart разбирает их ДО
/// инициализации go_router (см. vkCallbackInitialRoute) и стартует сразу
/// на нужном экране.
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

  static void startVkLogin() {
    if (!isVkConfigured) {
      throw StateError('Вход через VK не настроен: не задан VK_CLIENT_ID при сборке.');
    }
    final codeVerifier = _generateRandomString(64);
    final codeChallenge = _codeChallengeFor(codeVerifier);
    final state = _generateRandomString(40);
    platform.savePkce(codeVerifier: codeVerifier, state: state);

    final uri = Uri.https('id.vk.ru', '/authorize', {
      'response_type': 'code',
      'client_id': Env.vkClientId,
      'redirect_uri': vkRedirectUri(),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'scope': 'email',
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

  /// Вызывается из main.dart ДО создания GoRouter. Если текущий адрес —
  /// это возврат от VK ID (есть "code"/"device_id" после успешного входа
  /// или "error" после отказа), возвращает начальный маршрут для GoRouter
  /// с этими параметрами плюс сохранённый ранее code_verifier; иначе null
  /// (обычный запуск приложения). Заодно стирает query из адресной строки
  /// и сохранённую PKCE-пару, чтобы код не переиспользовался повторно при
  /// обновлении страницы.
  static String? vkCallbackInitialRoute() {
    final params = Uri.base.queryParameters;
    if (!params.containsKey('code') && !params.containsKey('device_id') && !params.containsKey('error')) return null;

    final pkce = platform.readAndClearPkce();
    platform.clearBootQuery();

    final routeParams = <String, String>{...params};
    // state, вернувшийся от VK, должен совпадать с тем, что мы сохранили
    // перед редиректом — иначе ответ нельзя доверять (см. доку VK ID).
    // code_verifier же VK вообще не возвращает, его подставляем сами.
    final returnedState = params['state'];
    final stateMatches = pkce.state != null && pkce.state == returnedState;
    if (params.containsKey('code') && stateMatches && pkce.codeVerifier != null) {
      routeParams['codeVerifier'] = pkce.codeVerifier!;
    } else if (params.containsKey('code')) {
      routeParams.remove('code');
      routeParams['error'] = 'state_mismatch';
    }
    return Uri(path: '/auth/vk-callback', queryParameters: routeParams).toString();
  }

  static const _codeVerifierAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// Криптостойкая случайная строка для PKCE code_verifier/state — только
  /// символы из RFC 7636 (a-z, A-Z, 0-9, -, ., _, ~).
  static String _generateRandomString(int length) {
    final random = Random.secure();
    return List.generate(length, (_) => _codeVerifierAlphabet[random.nextInt(_codeVerifierAlphabet.length)]).join();
  }

  /// code_challenge = BASE64URL(SHA256(code_verifier)), без паддинга —
  /// именно так требует RFC 7636 / документация VK ID.
  static String _codeChallengeFor(String codeVerifier) {
    final hash = sha256.convert(ascii.encode(codeVerifier)).bytes;
    return base64Url.encode(hash).replaceAll('=', '');
  }
}
