import 'package:shared_preferences/shared_preferences.dart';

/// Локально сохранённая сессия пользователя: JWT-токен, выданный backend'ом
/// при регистрации/входе (см. backend/src/modules/auth). Пока токен есть —
/// приложение считает пользователя вошедшим и не просит логиниться заново
/// при каждом запуске (см. main.dart и core/router/app_router.dart).
abstract final class Session {
  static const _tokenKey = 'razvit_auth_token';
  static String? _token;

  /// Нужно вызвать один раз при старте приложения, до первого сетевого
  /// запроса и до построения роутера (см. main.dart).
  static Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  static String? get token => _token;

  static bool get isLoggedIn => _token != null;

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clear() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
