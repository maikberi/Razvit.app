import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Мишка RAZVIT — маскот-ассистент (в духе совы Duolingo), сопровождает
/// регистрацию и подсказывает по всему приложению.
class RazvitMascot extends StatefulWidget {
  const RazvitMascot({super.key, this.size = 72});

  final double size;

  @override
  State<RazvitMascot> createState() => _RazvitMascotState();
}

class _RazvitMascotState extends State<RazvitMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
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
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -4 * _controller.value),
        child: child,
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.greenGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.all(widget.size * 0.06),
          child: Image.asset('assets/mascot/bear.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Мишка + анимированный «пузырь» с репликой — реакция на действия
/// пользователя (регистрация, подсказки на главной и т.д.).
class MascotBubble extends StatelessWidget {
  const MascotBubble({super.key, required this.text, this.mascotSize = 56});

  final String text;
  final double mascotSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RazvitMascot(size: mascotSize),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(AppRadius.md),
                bottomLeft: Radius.circular(AppRadius.md),
                bottomRight: Radius.circular(AppRadius.md),
              ),
              boxShadow: AppShadows.card,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(text, key: ValueKey(text), style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ),
      ],
    );
  }
}
