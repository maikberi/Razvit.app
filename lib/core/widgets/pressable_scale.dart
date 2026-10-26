import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Обёртка с лёгким "нажатием" (масштаб + haptic) — тактильная обратная
/// связь для интерактивных карточек выбора, как в топовых приложениях.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.onTap, required this.child, this.haptic = true});

  final VoidCallback onTap;
  final Widget child;
  final bool haptic;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: () {
        if (widget.haptic) HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
