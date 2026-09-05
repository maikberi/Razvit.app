import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/user.dart';

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
    return GestureDetector(
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
            if (selected)
              const Positioned(top: 0, right: 0, child: Icon(Icons.check_circle_rounded, color: AppColors.green500, size: 18)),
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
    return GestureDetector(
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
              if (selected)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(radius: 11, backgroundColor: Colors.white, child: Icon(Icons.check_rounded, color: AppColors.green600, size: 14)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Упрощённая схема тела для вопроса про травмы/ограничения — рисуется
/// сама (без лицензированных изображений), с пульсирующими зонами.
class BodyDiagram extends StatelessWidget {
  const BodyDiagram({super.key, required this.selected, required this.onToggle});

  final Set<BodyLimitation> selected;
  final ValueChanged<BodyLimitation> onToggle;

  @override
  Widget build(BuildContext context) {
    const width = 180.0;
    const height = 260.0;
    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            CustomPaint(size: const Size(width, height), painter: _BodySilhouettePainter(dark: context.isDarkMode)),
            _zone(context, top: 62, left: 22, limitation: BodyLimitation.shoulders),
            _zone(context, top: 62, left: width - 22 - 24, limitation: BodyLimitation.shoulders),
            _zone(context, top: 118, left: 8, limitation: BodyLimitation.elbows),
            _zone(context, top: 118, left: width - 8 - 24, limitation: BodyLimitation.elbows),
            _zone(context, top: 96, left: width / 2 - 12, limitation: BodyLimitation.back),
            _zone(context, top: 208, left: width / 2 - 44, limitation: BodyLimitation.knees),
            _zone(context, top: 208, left: width / 2 + 20, limitation: BodyLimitation.knees),
          ],
        ),
      ),
    );
  }

  Widget _zone(BuildContext context, {required double top, required double left, required BodyLimitation limitation}) {
    final isSelected = selected.contains(limitation);
    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onTap: () => onToggle(limitation),
        child: _PulseDot(active: isSelected),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.active});
  final bool active;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink400, width: 1.5)),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + _controller.value * 0.35;
        return Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.green500.withValues(alpha: 0.35))),
              ),
              Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.green500)),
            ],
          ),
        );
      },
    );
  }
}

class _BodySilhouettePainter extends CustomPainter {
  _BodySilhouettePainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dark ? AppColors.ink700 : AppColors.ink200;
    final w = size.width;

    // Голова.
    canvas.drawCircle(Offset(w / 2, 22), 18, paint);
    // Торс.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - 30, 46, 60, 100), const Radius.circular(24)),
      paint,
    );
    // Руки.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - 52, 54, 18, 90), const Radius.circular(9)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 + 34, 54, 18, 90), const Radius.circular(9)), paint);
    // Ноги.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - 26, 148, 22, 100), const Radius.circular(11)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 + 4, 148, 22, 100), const Radius.circular(11)), paint);
  }

  @override
  bool shouldRepaint(covariant _BodySilhouettePainter oldDelegate) => oldDelegate.dark != dark;
}
