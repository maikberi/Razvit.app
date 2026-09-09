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

class GoogleAuthResult extends AuthResult {
  const GoogleAuthResult({required super.token, required super.user, required this.isNewUser});

  final bool isNewUser;

  factory GoogleAuthResult.fromJson(Map<String, dynamic> json) => GoogleAuthResult(
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

  Future<GoogleAuthResult> loginWithGoogle(String idToken) async {
    final json = await _client.postJson('/api/v1/auth/google', {'idToken': idToken});
    return GoogleAuthResult.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<AuthUser> me() async {
    final json = await _client.getJson('/api/v1/auth/me');
    return AuthUser.fromJson(json['data'] as Map<String, dynamic>);
  }
}

final authApiServiceProvider = Provider<AuthApiService>((ref) => AuthApiService());
