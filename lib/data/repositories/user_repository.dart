import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/session.dart';
import '../models/user.dart';
import '../services/auth_api_service.dart';

class UserNotifier extends StateNotifier<AppUser> {
  UserNotifier({AppUser? initial})
      : super(initial ??
            const AppUser(
              id: '',
              name: '',
              email: '',
            ));

  void setFromAuth(AuthUser user) {
    state = AppUser(id: user.id, name: user.name, email: user.email);
  }

  void logWeight(double weightKg) {
    state = state.copyWith(weightKg: weightKg);
  }

  void updateProfile(
      {String? name, String? lastName, String? nickname, String? email}) {
    state = state.copyWith(
        name: name, lastName: lastName, nickname: nickname, email: email);
  }
}

final userProvider =
    StateNotifierProvider<UserNotifier, AppUser>((ref) => UserNotifier());

/// Простой флаг "прошёл ли пользователь онбординг" — определяет
/// стартовый экран приложения.
class OnboardingCompletionNotifier extends StateNotifier<bool> {
  OnboardingCompletionNotifier() : super(false);
  void complete() => state = true;
}

final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingCompletionNotifier, bool>(
        (ref) => OnboardingCompletionNotifier());

enum AuthStatus { checking, authenticated, unauthenticated }

/// Настоящая авторизация: регистрация/вход идут через backend
/// (modules/auth), токен сохраняется на устройстве (core/session/session.dart)
/// и переживает перезапуск приложения — при старте main.dart сам проверяет
/// сохранённый токен через /auth/me ещё до первого кадра (см. main.dart),
/// поэтому здесь `checking` практически никогда не остаётся надолго.
class AuthNotifier extends StateNotifier<AuthStatus> {
  AuthNotifier(this._ref, {AuthStatus initial = AuthStatus.unauthenticated})
      : super(initial);

  final Ref _ref;
  AuthApiService get _service => _ref.read(authApiServiceProvider);

  Future<void> register(
      {required String email,
      required String password,
      required String name}) async {
    final result =
        await _service.register(email: email, password: password, name: name);
    await Session.setToken(result.token);
    _ref.read(userProvider.notifier).setFromAuth(result.user);
    state = AuthStatus.authenticated;
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _service.login(email: email, password: password);
    await Session.setToken(result.token);
    _ref.read(userProvider.notifier).setFromAuth(result.user);
    state = AuthStatus.authenticated;
  }

  /// Вход через Google — [idToken] получен от google_sign_in на клиенте,
  /// backend сам проверяет его подлинность и создаёт/находит пользователя.
  Future<bool> loginWithGoogle(String idToken) => _completeSocialLogin(_service.loginWithGoogle(idToken));

  /// Вход через VK ID — параметры получены из редиректа обратно от VK
  /// (см. core/auth/social_redirect_gateway.dart и VkCallbackScreen),
  /// backend сам обменивает их на данные пользователя (PKCE-обмен кода
  /// на токен на стороне сервера).
  Future<bool> loginWithVk({
    required String code,
    required String deviceId,
    required String codeVerifier,
    required String redirectUri,
    required String state,
  }) =>
      _completeSocialLogin(_service.loginWithVk(
        code: code,
        deviceId: deviceId,
        codeVerifier: codeVerifier,
        redirectUri: redirectUri,
        state: state,
      ));

  /// Вход через Telegram Login — [payload] это поля из редиректа Telegram
  /// (id, first_name, ..., hash), backend сам проверяет подпись.
  Future<bool> loginWithTelegram(Map<String, dynamic> payload) =>
      _completeSocialLogin(_service.loginWithTelegram(payload));

  /// Общий хвост входа через соцсеть: сохранить токен, обновить
  /// пользователя, отметить сессию активной. Возвращает true, если аккаунт
  /// создан только что (тогда экран должен повести на онбординг), false —
  /// если это уже существующий пользователь (тогда сразу на /home, как при
  /// обычном логине).
  Future<bool> _completeSocialLogin(Future<SocialAuthResult> pending) async {
    final result = await pending;
    await Session.setToken(result.token);
    _ref.read(userProvider.notifier).setFromAuth(result.user);
    state = AuthStatus.authenticated;
    return result.isNewUser;
  }

  /// Временный локальный вход для кнопки Apple на экране выбора способа
  /// регистрации — реального Sign in with Apple пока нет, поэтому сессия
  /// НЕ сохраняется и не переживёт перезапуск (в отличие от входа по
  /// email/паролю и через Google/VK/Telegram). См. sign_up_method_screen.dart.
  void signInLocalOnly() => state = AuthStatus.authenticated;

  void signOut() {
    Session.clear();
    state = AuthStatus.unauthenticated;
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthStatus>((ref) => AuthNotifier(ref));
