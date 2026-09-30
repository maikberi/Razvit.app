import 'package:flutter/material.dart';

/// Мягкие тени для белых карточек — часть фирменного визуального языка.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F111827),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x14111827),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x3322C55E),
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> none = [];
}
