import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/workout.dart';

class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, this.onTap});

  final WorkoutProgram program;
  final VoidCallback? onTap;

  static const _tints = [
    Color(0xFF16A34A),
    Color(0xFF0EA5E9),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final tint = _tints[program.imageSeed % _tints.length];
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.fitness_center_rounded, color: tint, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        program.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${program.currentWeek}/${program.totalWeeks} нед',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${program.level.label} · ${program.totalWeeks} недель', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: program.progress,
                    minHeight: 5,
                    backgroundColor: AppColors.ink100,
                    valueColor: AlwaysStoppedAnimation(tint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
