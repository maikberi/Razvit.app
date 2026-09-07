import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable_scale.dart';

/// Мягкая волнообразная подложка внизу экрана — фирменный акцент онбординга.
/// Медленно «дышит» по горизонтали, ничего не перехватывает (IgnorePointer).
class OnboardingWaveBackground extends StatefulWidget {
  const OnboardingWaveBackground({super.key});

  @override
  State<OnboardingWaveBackground> createState() => _OnboardingWaveBackgroundState();
}

class _OnboardingWaveBackgroundState extends State<OnboardingWaveBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _WavePainter(progress: _controller.value, dark: context.isDarkMode),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.progress, required this.dark});
  final double progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final baseOpacity = dark ? 0.10 : 0.55;
    final layers = [
      (AppColors.green200, 0.85, 0.0),
      (AppColors.green300, 0.65, 0.33),
      (AppColors.green400, 0.45, 0.66),
    ];
    for (final (color, heightFactor, phaseOffset) in layers) {
      final path = Path();
      final baseY = size.height * (1 - heightFactor * 0.16);
      final phase = (progress + phaseOffset) * 2 * math.pi;
      path.moveTo(0, size.height);
      path.lineTo(0, baseY);
      const steps = 40;
      for (var i = 0; i <= steps; i++) {
        final x = size.width * i / steps;
        final y = baseY + math.sin((i / steps) * 2 * math.pi + phase) * 14;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: baseOpacity * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.dark != dark;
}

/// Карточка-плитка для сетки 2xN (например, выбор цели): иконка сверху,
/// подпись снизу, галочка в углу при выборе.
class SelectableTileCard extends StatelessWidget {
  const SelectableTileCard({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? (isDark ? AppColors.green500.withValues(alpha: 0.18) : AppColors.green50) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? AppColors.green500 : Theme.of(context).dividerColor, width: selected ? 1.5 : 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 10),
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                child: const Icon(Icons.check_circle_rounded, color: AppColors.green500, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Фото»-плитка для выбора места тренировки — вместо лицензированных
/// стоковых фото используем градиент + иконку в том же формфакторе.
class PlacePhotoTile extends StatelessWidget {
  const PlacePhotoTile({
    super.key,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.15,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: selected ? Border.all(color: AppColors.green500, width: 2.5) : null,
          ),
          child: Stack(
            children: [
              Center(child: Icon(icon, color: Colors.white, size: 34)),
              Positioned(
                left: 10,
                bottom: 10,
                child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  child: const CircleAvatar(radius: 11, backgroundColor: Colors.white, child: Icon(Icons.check_rounded, color: AppColors.green600, size: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

