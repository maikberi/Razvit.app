import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mascot.dart';
import '../../../core/widgets/razvit_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const RazvitMark(size: 128),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Добро пожаловать\nв RAZVIT',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Твой путь к лучшей версии себя',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _FeatureRow(icon: Icons.assignment_outlined, text: 'Персональный план тренировок и питания'),
              const SizedBox(height: AppSpacing.md),
              const _FeatureRow(icon: Icons.insights_rounded, text: 'Контроль прогресса и аналитика'),
              const SizedBox(height: AppSpacing.md),
              const _FeatureRow(icon: Icons.auto_awesome_rounded, text: 'Поддержка AI-наставника 24/7'),
              const SizedBox(height: AppSpacing.lg),
              const MascotBubble(text: 'Привет! Я твой AI-ассистент, помогу тебе начать 👋', mascotSize: 48),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: () => context.push('/register'),
                child: const Text('Начать'),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Уже есть аккаунт?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Войти'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(icon, color: AppColors.green600, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}
