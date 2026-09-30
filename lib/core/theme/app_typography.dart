import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Типографика RAZVIT — на iOS/macOS используется настоящий системный
/// SF Pro Rounded (Apple лицензирует его только для своих платформ, вшить
/// сам файл в кроссплатформенное приложение нельзя). На остальных
/// платформах — Inter: чистый нейтральный гротеск с полной поддержкой
/// кириллицы, тот же класс шрифта, что и в большинстве современных
/// premium-приложений (в духе Apple/Yazio). Раньше здесь был Nunito
/// (переменный шрифт) — из-за особенностей резолва переменных шрифтов на
/// вебе через CanvasKit/Skia он местами откатывался к весу по умолчанию
/// (200, тончайшему), из-за чего текст выглядел "не таким, как раньше" —
/// см. fonts/*.ttf: теперь каждый вес — отдельный статичный файл, этот
/// риск исключён в принципе.
///
/// Шрифт вшит в приложение как ассет (см. pubspec.yaml, fonts/Inter-*.ttf),
/// а не через google_fonts — тот подгружал файл с fonts.gstatic.com при
/// каждом холодном запуске, и именно это, судя по всему, было главной
/// причиной "очень долго грузит": тот же класс проблем, что и с GIF
/// упражнений на стороннем CDN (см. self-hosting в web/exercises/), только
/// здесь тормозил КАЖДЫЙ экран, а не только раздел тренировок.
abstract final class AppTypography {
  static bool get _useSystemAppleRounded =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  static TextStyle _style({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: _useSystemAppleRounded ? '.SF Pro Rounded' : 'Inter',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextTheme textTheme(Color base, {Color? secondary}) {
    final muted = secondary ?? AppColors.ink500;
    const theme = TextTheme();
    return theme.copyWith(
      displayLarge: _style(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        color: base,
        letterSpacing: -0.3,
        height: 1.15,
      ),
      headlineLarge: _style(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: base,
        letterSpacing: -0.2,
        height: 1.2,
      ),
      headlineMedium: _style(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: base,
        letterSpacing: -0.2,
        height: 1.2,
      ),
      titleLarge: _style(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: base,
        height: 1.3,
      ),
      titleMedium: _style(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: base,
        height: 1.3,
      ),
      titleSmall: _style(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: base,
        height: 1.3,
      ),
      bodyLarge: _style(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: base,
        height: 1.45,
      ),
      bodyMedium: _style(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: base,
        height: 1.45,
      ),
      bodySmall: _style(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: muted,
        height: 1.4,
      ),
      labelLarge: _style(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: base,
        letterSpacing: 0.1,
      ),
      labelMedium: _style(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: base,
        letterSpacing: 0.1,
      ),
      labelSmall: _style(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: muted,
        letterSpacing: 0.2,
      ),
    );
  }
}
