import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const foodBadgeColors = [AppColors.green600, Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEC4899)];

Color foodBadgeColor(String id) => foodBadgeColors[id.hashCode.abs() % foodBadgeColors.length];
