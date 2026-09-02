import 'package:flutter/material.dart';

/// Фирменная цветовая палитра RAZVIT.
abstract final class AppColors {
  // Брендовый зелёный и его оттенки.
  static const Color green50 = Color(0xFFEFFDF4);
  static const Color green100 = Color(0xFFD8FBE4);
  static const Color green200 = Color(0xFFB0F5CB);
  static const Color green300 = Color(0xFF7BE8A9);
  static const Color green400 = Color(0xFF4AD787);
  static const Color green500 = Color(0xFF22C55E); // основной бренд-цвет
  static const Color green600 = Color(0xFF16A34A);
  static const Color green700 = Color(0xFF15803D);
  static const Color green800 = Color(0xFF166534);
  static const Color green900 = Color(0xFF14532D);

  // Тёмная гамма (текст, тёмные экраны — например, выполнение тренировки).
  static const Color ink900 = Color(0xFF111827);
  static const Color ink800 = Color(0xFF1F2937);
  static const Color ink700 = Color(0xFF374151);
  static const Color ink600 = Color(0xFF4B5563);
  static const Color ink500 = Color(0xFF6B7280);
  static const Color ink400 = Color(0xFF9CA3AF);
  static const Color ink300 = Color(0xFFD1D5DB);
  static const Color ink200 = Color(0xFFE5E7EB);
  static const Color ink100 = Color(0xFFF3F4F6); // светлый фон
  static const Color ink50 = Color(0xFFF9FAFB);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Семантика.
  static const Color success = green500;
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Индикаторы БЖУ на графиках.
  static const Color protein = Color(0xFF3B82F6);
  static const Color fat = Color(0xFFF59E0B);
  static const Color carbs = green500;
  static const Color water = Color(0xFF38BDF8);

  // Поверхности.
  static const Color surface = white;
  static const Color background = ink100;
  static const Color darkSurface = ink900;
  static const Color darkSurfaceElevated = ink800;

  // Тени/границы.
  static const Color border = ink200;
  static const Color shadow = Color(0x1A111827);

  static const List<Color> greenGradient = [green400, green600];
  static const List<Color> darkGradient = [ink800, ink900];
}
