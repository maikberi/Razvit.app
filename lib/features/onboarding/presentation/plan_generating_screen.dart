import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/razvit_logo.dart';

class PlanGeneratingScreen extends StatefulWidget {
  const PlanGeneratingScreen({super.key});

  @override
  State<PlanGeneratingScreen> createState() => _PlanGeneratingScreenState();
}

class _PlanGeneratingScreenState extends State<PlanGeneratingScreen> with SingleTickerProviderStateMixin {
  static const _steps = [
    'Анализируем данные',
    'Подбираем тренировки',
    'Рассчитываем нагрузку',
    'Подбираем питание',
    'Настраиваем рекомендации',
  ];

  int _visible = 0;
  Timer? _timer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      setState(() => _visible++);
      if (_visible >= _steps.length) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.pushReplacement('/plan-motivation');
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Transform.scale(scale: 1 + _pulseController.value * 0.08, child: child),
                  child: const RazvitMark(size: 64),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Создаём твой\nперсональный план...', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xxl),
                for (var i = 0; i < _steps.length; i++)
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    offset: i <= _visible ? Offset.zero : const Offset(-0.05, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: i < _visible ? 1 : 0.25,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            i < _visible
                                ? const AnimatedScale(
                                    scale: 1,
                                    duration: Duration(milliseconds: 350),
                                    curve: Curves.elasticOut,
                                    child: Icon(Icons.check_circle_rounded, color: AppColors.green500, size: 20),
                                  )
                                : const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink300),
                                  ),
                            const SizedBox(width: 12),
                            Text(_steps[i], style: Theme.of(context).textTheme.bodyLarge),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
