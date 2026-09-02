import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Фирменный знак RAZVIT — стилизованный лист/сердце в круге.
/// Используется как временная замена финального логотипа заказчика.
class RazvitMark extends StatelessWidget {
  const RazvitMark({super.key, this.size = 32, this.background = AppColors.green500, this.foreground = AppColors.white});

  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Center(
        child: Icon(Icons.eco_rounded, color: foreground, size: size * 0.6),
      ),
    );
  }
}

class RazvitWordmark extends StatelessWidget {
  const RazvitWordmark({super.key, this.iconSize = 28, this.fontSize = 20, this.color});

  final double iconSize;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink900;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RazvitMark(size: iconSize),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'RAZVIT',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: c,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                fontSize: fontSize,
              ),
        ),
      ],
    );
  }
}
