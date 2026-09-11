import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/auth/social_redirect_gateway.dart';
import 'core/network/api_client.dart';
import 'app.dart';
import 'core/router/app_router.dart' as router;
import 'core/session/session.dart';
import 'data/models/user.dart';
import 'data/repositories/user_repository.dart';
import 'data/services/auth_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  await Session.ensureLoaded();

  AppUser? restoredUser;
  final vkCallbackRoute = SocialRedirectGateway.vkCallbackInitialRoute();
  if (vkCallbackRoute != null) {
    // Вернулись из VK OAuth — сразу на экран обработки кода, сессию из
    // хранилища в этом случае не проверяем (VkCallbackScreen сам выставит
    // актуальную после успешного обмена кода на токен).
    router.initialRoute = vkCallbackRoute;
  } else if (Session.isLoggedIn) {
    try {
      final me = await _fetchCurrentUserWithRetry();
      restoredUser = AppUser(id: me.id, name: me.name, email: me.email);
      router.initialRoute = '/home';
    } on ApiException catch (e) {
      // Токен реально недействителен/просрочен (backend явно ответил 401) —
      // только тогда есть смысл разлогинивать. Любая другая ошибка (нет
      // сети, backend не успел подняться после "холодного старта" и т.п.)
      // не должна стирать токен — иначе временная сетевая заминка при
      // запуске выглядела бы как "постоянно приходится логиниться заново".
      if (e.statusCode == 401) {
        await Session.clear();
      }
    } catch (_) {
      // Непредвиденная ошибка — тоже не трогаем сохранённый токен.
    }
  }

  runApp(ProviderScope(
    overrides: [
      if (restoredUser != null) ...[
        userProvider.overrideWith((ref) => UserNotifier(initial: restoredUser)),
        authProvider.overrideWith((ref) => AuthNotifier(ref, initial: AuthStatus.authenticated)),
      ],
    ],
    child: const RazvitApp(),
  ));
}

/// Один повтор при сетевой ошибке/таймауте (не при 401 — там сразу выходим)
/// — Yandex Cloud Function может недолго "просыпаться" после простоя, и
/// один неудачный запрос на старте не должен выглядеть как разлогинивание.
Future<AuthUser> _fetchCurrentUserWithRetry() async {
  final service = AuthApiService();
  try {
    return await service.me();
  } on ApiException catch (e) {
    if (e.statusCode == 401) rethrow;
    await Future.delayed(const Duration(seconds: 2));
    return service.me();
  }
}
