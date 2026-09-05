import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'mascot.dart';

/// Полноэкранная мотивационная заставка с мишкой — крупная иллюстрация,
/// жирный заголовок и текст, кнопка «Далее». По образцу онбординга
/// топовых health-приложений, но в теме RAZVIT.
class MascotEncouragementScreen extends StatelessWidget {
  const MascotEncouragementScreen({
    super.key,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onNext,
    this.progress,
    this.onBack,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onNext;
  final double? progress;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _BackCircle(onTap: onBack ?? () => Navigator.of(context).maybePop()),
                  if (progress != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Theme.of(context).dividerColor,
                          color: AppColors.green500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Center(child: RazvitMascot(size: 220)),
              const SizedBox(height: AppSpacing.xxl),
              Text(title, style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: AppSpacing.md),
              Text(body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.ink500)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: onNext, child: Text(buttonLabel)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  const _BackCircle({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).cardTheme.color,
          boxShadow: AppShadows.card,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      ),
    );
  }
}
