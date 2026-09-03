import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Типографика RAZVIT — Nunito: круглый, дружелюбный гротеск в духе
/// Duolingo (их фирменный шрифт Feather кастомный и нигде не продаётся,
/// Nunito — ближайший открытый аналог с полной поддержкой кириллицы).
abstract final class AppTypography {
  static TextStyle _style({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextTheme textTheme(Color base) {
    final theme = GoogleFonts.nunitoTextTheme();
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
        color: AppColors.ink500,
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
        color: AppColors.ink500,
        letterSpacing: 0.2,
      ),
    );
  }
}
