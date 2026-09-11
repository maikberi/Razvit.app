import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/workout.dart';

class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, this.onTap});

  final WorkoutProgram program;
  final VoidCallback? onTap;

  static const _gradients = [
    [Color(0xFF16A34A), Color(0xFF111827)],
    [Color(0xFF0EA5E9), Color(0xFF111827)],
    [Color(0xFFF59E0B), Color(0xFF111827)],
    [Color(0xFF8B5CF6), Color(0xFF111827)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[program.imageSeed % _gradients.length];
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text('${program.level.label} · ${program.totalWeeks} недель', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(value: program.progress, minHeight: 5, backgroundColor: AppColors.ink100),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${program.currentWeek}/${program.totalWeeks} нед', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
