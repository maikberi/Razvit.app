import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../session/session.dart';

/// Ошибка обращения к backend. [statusCode] == null означает сетевую
/// проблему (нет интернета/сервер недоступен/таймаут) — отличаем от
/// ответа backend с ошибкой (тогда statusCode/code заполнены).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isNetworkError => statusCode == null;

  @override
  String toString() => 'ApiException(status: $statusCode, code: $code): $message';
}

/// Единственная точка обращения к backend RAZVIT из Flutter.
/// Никакие внешние API (Open Food Facts, USDA и т.д.) больше не вызываются
/// напрямую с клиента — только через этот клиент и backend.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Env.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    final token = Session.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    return _send(() => _client.get(uri, headers: _headers).timeout(const Duration(seconds: 8)));
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(() => _client.post(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 8)));
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body) {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(() => _client.put(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 8)));
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body) {
    final uri = Uri.parse('$_baseUrl$path');
    return _send(() => _client.patch(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 8)));
  }

  Future<Map<String, dynamic>> delete(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    return _send(() => _client.delete(uri, headers: _headers).timeout(const Duration(seconds: 8)));
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (_) {
      throw ApiException('Не удалось подключиться к серверу. Проверь интернет и попробуй ещё раз.');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty ? const {} : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Некорректный ответ сервера', statusCode: response.statusCode);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = decoded['error'] as Map<String, dynamic>?;
    throw ApiException(
      (error?['message'] as String?) ?? 'Что-то пошло не так на сервере',
      statusCode: response.statusCode,
      code: error?['code'] as String?,
    );
  }
}
