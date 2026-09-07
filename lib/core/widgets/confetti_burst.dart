import 'dart:math';

import 'package:flutter/material.dart';

/// Праздничное конфетти, один раз разлетающееся сверху вниз при
/// появлении экрана — для celebratory-моментов вроде готового плана.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.particleCount = 70});
  final int particleCount;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  static const _colors = [
    AppColorsInternal.green,
    AppColorsInternal.amber,
    AppColorsInternal.blue,
    AppColorsInternal.pink,
    AppColorsInternal.white,
    AppColorsInternal.purple,
  ];

  @override
  void initState() {
    super.initState();
    final random = Random();
    _particles = List.generate(
      widget.particleCount,
      (_) => _Particle(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.35,
        fallSpeed: 0.6 + random.nextDouble() * 0.5,
        drift: (random.nextDouble() - 0.5) * 0.3,
        size: 6 + random.nextDouble() * 7,
        color: _colors[random.nextInt(_colors.length)],
        rotationSpeed: (random.nextDouble() - 0.5) * 8,
        isCircle: random.nextBool(),
      ),
    );
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..forward();
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
          painter: _ConfettiPainter(particles: _particles, t: _controller.value),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.delay,
    required this.fallSpeed,
    required this.drift,
    required this.size,
    required this.color,
    required this.rotationSpeed,
    required this.isCircle,
  });

  final double x;
  final double delay;
  final double fallSpeed;
  final double drift;
  final double size;
  final Color color;
  final double rotationSpeed;
  final bool isCircle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.t});
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final localT = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final y = -20 + localT * (size.height + 40) * p.fallSpeed;
      if (y > size.height + 20) continue;
      final x = p.x * size.width + sin(localT * 6) * p.drift * size.width * 0.3;
      final opacity = localT > 0.85 ? (1 - (localT - 0.85) / 0.15).clamp(0.0, 1.0) : 1.0;
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(localT * p.rotationSpeed * pi);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

/// Небольшая festive-палитра для конфетти — не завязана на основную
/// тему, чтобы виджет оставался переиспользуемым сам по себе.
abstract class AppColorsInternal {
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
  static const blue = Color(0xFF3B82F6);
  static const pink = Color(0xFFEC4899);
  static const white = Color(0xFFFFFFFF);
  static const purple = Color(0xFF8B5CF6);
}
