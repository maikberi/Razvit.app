import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  if (Session.isLoggedIn) {
    try {
      final me = await AuthApiService().me();
      restoredUser = AppUser(id: me.id, name: me.name, email: me.email);
      router.initialRoute = '/home';
    } catch (_) {
      // Токен просрочен/недействителен — начинаем как неавторизованный.
      await Session.clear();
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
