import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const foodBadgeColors = [AppColors.green600, Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEC4899)];

Color foodBadgeColor(String id) => foodBadgeColors[id.hashCode.abs() % foodBadgeColors.length];

/// Круглая миниатюра продукта: фото, если у продукта оно есть (сейчас
/// реально приходит только от Open Food Facts), иначе — тот же цветной
/// значок-заглушка, что был раньше везде. Фото показывается только после
/// успешной загрузки — до и в случае ошибки виден значок, чтобы никогда
/// не было пустого места или "прыжка" макета.
class FoodThumbnail extends StatelessWidget {
  const FoodThumbnail({super.key, required this.id, required this.imageUrl, required this.size, this.iconSize});

  final String id;
  final String? imageUrl;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final color = foodBadgeColor(id);
    final icon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(Icons.restaurant_rounded, color: color, size: iconSize ?? size * 0.45),
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return icon;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) => progress == null ? child : icon,
          errorBuilder: (context, error, stackTrace) => icon,
        ),
      ),
    );
  }
}
