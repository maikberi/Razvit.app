import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/razvit_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Theme.of(context).scaffoldBackgroundColor),
          const _BackgroundBlobs(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlideIn(child: const RazvitWordmark(iconSize: 32, fontSize: 24)),
                      const SizedBox(height: 6),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: Text(
                          'Твой путь к лучшей версии себя',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.ink500),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, scale, child) => Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child),
                    child: SizedBox(
                      width: double.infinity,
                      child: Image.asset(
                        'assets/mascot/welcome_bear.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
                      Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
                child: Column(
                  children: [
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        onPressed: () => context.push('/sign-up-method'),
                        child: const Text('Начать'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 260),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Уже есть аккаунт?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                          TextButton(
                            onPressed: () => context.push('/login'),
                            child: const Text('Войти'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Мягкие размытые зелёные пятна фоном — фирменный акцент welcome-экрана.
class _BackgroundBlobs extends StatelessWidget {
  const _BackgroundBlobs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -90,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.green200.withValues(alpha: 0.55)),
              ),
            ),
          ),
          Positioned(
            top: 130,
            right: -60,
            child: Transform.rotate(
              angle: -0.4,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                child: Container(
                  width: 240,
                  height: 100,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(60), color: AppColors.green100.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 40,
            child: Transform.rotate(
              angle: 0.5,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
                child: Container(
                  width: 140,
                  height: 60,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), color: AppColors.green300.withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
