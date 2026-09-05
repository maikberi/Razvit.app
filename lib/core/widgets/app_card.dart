import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Базовая белая карточка с мягкой тенью — основной строительный блок UI.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.radius = AppRadius.lg,
    this.shadow = true,
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final bool shadow;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardTheme.color ?? AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ? AppShadows.card : null,
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}
