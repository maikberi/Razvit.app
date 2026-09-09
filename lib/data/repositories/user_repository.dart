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

  /// Временный локальный вход для кнопок Google/Apple/Telegram/VK на экране
  /// выбора способа регистрации — реального OAuth с этими провайдерами
  /// пока нет, поэтому сессия НЕ сохраняется и не переживёт перезапуск
  /// (в отличие от входа по email/паролю). См. sign_up_method_screen.dart.
  void signInLocalOnly() => state = AuthStatus.authenticated;

  void signOut() {
    Session.clear();
    state = AuthStatus.unauthenticated;
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthStatus>((ref) => AuthNotifier(ref));
