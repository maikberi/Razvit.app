import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

class RazvitApp extends ConsumerWidget {
  const RazvitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'RAZVIT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => _ImagePrecacher(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Прогревает кэш растровых изображений сразу после первого кадра, чтобы
/// они не "выскакивали" с задержкой при первом появлении на экране.
class _ImagePrecacher extends StatefulWidget {
  const _ImagePrecacher({required this.child});
  final Widget child;

  @override
  State<_ImagePrecacher> createState() => _ImagePrecacherState();
}

class _ImagePrecacherState extends State<_ImagePrecacher> {
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final asset in const [
        'assets/mascot/bear.png',
        'assets/home/hero_dumbbells.png',
      ]) {
        precacheImage(AssetImage(asset), context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
