import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Временная замена полноценной авторизации: один раз генерируется UUID
/// устройства/установки, сохраняется локально и отправляется backend'у
/// в заголовке X-Device-Id (см. backend/src/middleware/deviceUser.ts) —
/// так у каждого пользователя свои приёмы пищи/цели/вода уже сейчас, ещё
/// до появления настоящего входа в аккаунт. Когда появится реальная
/// авторизация, этот id заменится на id из сессии — весь остальной код,
/// который просто читает `DeviceIdentity.current`, менять не придётся.
abstract final class DeviceIdentity {
  static const _prefsKey = 'razvit_device_id';
  static String? _cached;

  /// Нужно вызвать один раз при старте приложения, до первого сетевого
  /// запроса (см. main.dart).
  static Future<void> ensureLoaded() async {
    if (_cached != null) return;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null) {
      id = _generateUuidV4();
      await prefs.setString(_prefsKey, id);
    }
    _cached = id;
  }

  static String get current {
    final id = _cached;
    if (id == null) {
      throw StateError('DeviceIdentity.ensureLoaded() must be awaited before use (see main.dart)');
    }
    return id;
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // версия 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // вариант RFC 4122
    String hex(int start, int end) => bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
