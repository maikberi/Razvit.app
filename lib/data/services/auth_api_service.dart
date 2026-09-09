import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
      );
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final AuthUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// Результат входа через соцсеть (Google/VK/Telegram) — то же, что обычный
/// AuthResult, плюс признак "аккаунт только что создан" (чтобы фронт решил,
/// вести на онбординг или сразу на /home, см. AuthNotifier).
class SocialAuthResult extends AuthResult {
  const SocialAuthResult({required super.token, required super.user, required this.isNewUser});

  final bool isNewUser;

  factory SocialAuthResult.fromJson(Map<String, dynamic> json) => SocialAuthResult(
        token: json['token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
        isNewUser: json['isNewUser'] as bool,
      );
}

/// Регистрация/вход/текущий пользователь — единственный модуль, который
/// реально хранит пароли и выдаёт сессию (backend/src/modules/auth).
class AuthApiService {
  AuthApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<AuthResult> register({required String email, required String password, required String name}) async {
    final json = await _client.postJson('/api/v1/auth/register', {'email': email, 'password': password, 'name': name});
    return AuthResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final json = await _client.postJson('/api/v1/auth/login', {'email': email, 'password': password});
    return AuthResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<SocialAuthResult> loginWithGoogle(String idToken) async {
    final json = await _client.postJson('/api/v1/auth/google', {'idToken': idToken});
    return SocialAuthResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<SocialAuthResult> loginWithVk({required String code, required String redirectUri}) async {
    final json = await _client.postJson('/api/v1/auth/vk', {'code': code, 'redirectUri': redirectUri});
    return SocialAuthResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// [payload] — те же поля, что Telegram присылает в редиректе (id,
  /// first_name, ..., auth_date, hash) — передаются backend'у как есть,
  /// он сам их проверяет.
  Future<SocialAuthResult> loginWithTelegram(Map<String, dynamic> payload) async {
    final json = await _client.postJson('/api/v1/auth/telegram', payload);
    return SocialAuthResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<AuthUser> me() async {
    final json = await _client.getJson('/api/v1/auth/me');
    return AuthUser.fromJson(json['data'] as Map<String, dynamic>);
  }
}

final authApiServiceProvider = Provider<AuthApiService>((ref) => AuthApiService());
