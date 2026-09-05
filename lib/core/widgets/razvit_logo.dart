import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Фирменный знак RAZVIT — векторный логотип заказчика.
class RazvitMark extends StatelessWidget {
  const RazvitMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logo/razvit_mark.svg',
      width: size,
      height: size,
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
