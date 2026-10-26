import 'package:flutter/material.dart';

/// Эмодзи с мягкой зацикленной анимацией пульсации — используется для
/// «живых» акцентов вроде 🔥 на экране готового плана.
class AnimatedEmoji extends StatefulWidget {
  const AnimatedEmoji(this.emoji, {super.key, this.fontSize = 48});

  final String emoji;
  final double fontSize;

  @override
  State<AnimatedEmoji> createState() => _AnimatedEmojiState();
}

class _AnimatedEmojiState extends State<AnimatedEmoji> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _scale = Tween(begin: 0.92, end: 1.08).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotation = Tween(begin: -0.06, end: 0.06).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: _rotation.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: Text(widget.emoji, style: TextStyle(fontSize: widget.fontSize)),
    );
  }
}
