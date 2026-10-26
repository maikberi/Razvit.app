import 'package:google_sign_in/google_sign_in.dart';

import '../config/env.dart';

/// Тонкая обёртка над package:google_sign_in — единственное место в
/// приложении, которое знает про сам SDK Google. Возвращает id-токен,
/// который backend проверяет самостоятельно (POST /auth/google) — никакой
/// проверки подлинности на клиенте, только получение токена.
abstract final class GoogleAuthGateway {
  static GoogleSignIn? _instance;

  static bool get isConfigured => Env.googleClientId.isNotEmpty;

  static GoogleSignIn _signIn() {
    return _instance ??= GoogleSignIn(clientId: Env.googleClientId, scopes: const ['email']);
  }

  /// Открывает окно входа Google и возвращает id-токен, либо null, если
  /// пользователь закрыл окно, не выбрав аккаунт (не ошибка — просто отмена).
  static Future<String?> signInAndGetIdToken() async {
    if (!isConfigured) {
      throw StateError('Google Sign-In не настроен: не задан GOOGLE_CLIENT_ID при сборке.');
    }
    final account = await _signIn().signIn();
    if (account == null) return null; // пользователь отменил вход
    final auth = await account.authentication;
    return auth.idToken;
  }
}
