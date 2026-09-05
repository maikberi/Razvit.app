import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';

class UserNotifier extends StateNotifier<AppUser> {
  UserNotifier()
      : super(const AppUser(
          id: 'me',
          name: 'Михаил',
          email: 'you@example.com',
        ));

  void logWeight(double weightKg) {
    state = state.copyWith(weightKg: weightKg);
  }

  void updateProfile({String? name, String? lastName, String? nickname, String? email}) {
    state = state.copyWith(name: name, lastName: lastName, nickname: nickname, email: email);
  }
}

final userProvider = StateNotifierProvider<UserNotifier, AppUser>((ref) => UserNotifier());

/// Простой флаг "прошёл ли пользователь онбординг" — определяет
/// стартовый экран приложения.
class OnboardingCompletionNotifier extends StateNotifier<bool> {
  OnboardingCompletionNotifier() : super(false);
  void complete() => state = true;
}

final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingCompletionNotifier, bool>((ref) => OnboardingCompletionNotifier());

/// Флаг авторизации (mock) — управляет тем, показываем ли экраны Auth.
class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(false);
  void signIn() => state = true;
  void signOut() => state = false;
}

final authProvider = StateNotifierProvider<AuthNotifier, bool>((ref) => AuthNotifier());
