import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Карточка-опция для онбординга и фильтров: заголовок + галочка при выборе.
class SelectableOptionCard extends StatelessWidget {
  const SelectableOptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.iconColor = AppColors.green600,
    this.iconBackground = AppColors.green50,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isDark = context.isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? (isDark ? AppColors.green500.withValues(alpha: 0.18) : AppColors.green50) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.green500 : Theme.of(context).dividerColor, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(subtitle!, style: text.bodySmall),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.green500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Компактный чип-переключатель (для фильтров, дней недели и т.д.).
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 16, vertical: dense ? 9 : 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.green500 : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.green500 : Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (dense ? Theme.of(context).textTheme.labelSmall : Theme.of(context).textTheme.labelMedium)?.copyWith(
                color: selected ? AppColors.white : null,
              ),
        ),
      ),
    );
  }
}
