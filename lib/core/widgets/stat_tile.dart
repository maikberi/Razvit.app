import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_card.dart';

/// Компактная плитка показателя, например «1820 / 2300 ккал».
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.trend,
    this.trendUp,
    this.icon,
  });

  final String label;
  final String value;
  final String? unit;
  final String? trend;
  final bool? trendUp;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.ink400),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(label, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: text.titleLarge),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(unit!, style: text.bodySmall),
              ],
            ],
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Text(
              trend!,
              style: text.labelSmall?.copyWith(
                color: (trendUp ?? true) ? AppColors.green600 : AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
