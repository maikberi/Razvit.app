import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Слушает прокрутку и уведомляет зарегистрированные [RevealOnVisible],
/// когда нужно перепроверить свою видимость.
class RevealVisibilityScope extends StatefulWidget {
  const RevealVisibilityScope({super.key, required this.child});
  final Widget child;

  @override
  State<RevealVisibilityScope> createState() => RevealVisibilityScopeState();
}

class RevealVisibilityScopeState extends State<RevealVisibilityScope> {
  final List<VoidCallback> _checks = [];

  void register(VoidCallback check) => _checks.add(check);
  void unregister(VoidCallback check) => _checks.remove(check);

  void _checkAll() {
    for (final check in List<VoidCallback>.from(_checks)) {
      check();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _checkAll();
        return false;
      },
      child: widget.child,
    );
  }
}

/// Один раз проигрывает эффектное появление (рост + мягкое свечение),
/// когда виджет попадает в видимую область экрана — привлекает внимание
/// к главному экрану сразу после регистрации.
class RevealOnVisible extends StatefulWidget {
  const RevealOnVisible({super.key, required this.child, required this.active});

  final Widget child;
  final bool active;

  @override
  State<RevealOnVisible> createState() => _RevealOnVisibleState();
}

class _RevealOnVisibleState extends State<RevealOnVisible> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  RevealVisibilityScopeState? _scope;
  bool _played = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    if (!widget.active) {
      _controller.value = 1;
      _played = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope?.unregister(_check);
    _scope = context.findAncestorStateOfType<RevealVisibilityScopeState>();
    _scope?.register(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _scope?.unregister(_check);
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    if (_played || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final position = box.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    if (position.dy < screenHeight * 0.88 && position.dy > -box.size.height) {
      _played = true;
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(_controller.value.clamp(0.0, 1.0));
        final glow = (1 - _controller.value).clamp(0.0, 1.0);
        return Opacity(
          opacity: _controller.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.82 + 0.18 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: glow > 0.02
                    ? [BoxShadow(color: AppColors.green500.withValues(alpha: glow * 0.45), blurRadius: 28 * glow, spreadRadius: 1)]
                    : null,
              ),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
