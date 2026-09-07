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
      body: SafeArea(
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
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [AppColors.green100, Colors.transparent]),
                      ),
                    ),
                    Image.asset('assets/mascot/welcome_bear.png', fit: BoxFit.contain),
                  ],
                ),
              ),
            ),
            Padding(
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
          ],
        ),
      ),
    );
  }
}
