import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Заглушка-аватар: круг с инициалом и стабильным по seed цветом фона.
/// В проекте пока нет реальных фотографий пользователей/тренеров.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = 44, this.seed = 0});

  final String name;
  final double size;
  final int seed;

  static const _palette = [
    AppColors.green500,
    AppColors.ink700,
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[seed % _palette.length];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4),
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const Icon(Icons.verified_rounded, color: AppColors.green500, size: 16);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.green500, size: 14),
          const SizedBox(width: 4),
          Text(
            'Проверенный тренер',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.green700),
          ),
        ],
      ),
    );
  }
}

class TagBadge extends StatelessWidget {
  const TagBadge({super.key, required this.label, this.color = AppColors.green500});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
