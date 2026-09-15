import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Временный служебный экран для визуального сравнения шрифтов.
/// Не связан с основным приложением — доступен только по прямой ссылке.
class FontPreviewScreen extends StatelessWidget {
  const FontPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final family = GoRouterState.of(context).uri.queryParameters['family'] ?? 'Inter';

    TextStyle style({required double size, required FontWeight weight, Color color = AppColors.ink900, double? letterSpacing}) {
      return GoogleFonts.getFont(family, fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.ink900, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text(family, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Добрый день,', style: style(size: 26, weight: FontWeight.w800)),
              Text('Михаил! 👋', style: style(size: 26, weight: FontWeight.w800, color: AppColors.green600)),
              const SizedBox(height: 6),
              Text('Ты на шаг ближе к своей цели', style: style(size: 15, weight: FontWeight.w500, color: AppColors.ink500)),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.greenGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Сегодня по плану', style: style(size: 12, weight: FontWeight.w600, color: Colors.white70)),
                    Text('Push Day 💪', style: style(size: 22, weight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 14),
                    Text('6 упражнений · 55 минут', style: style(size: 13, weight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Калории', style: style(size: 12, weight: FontWeight.w600, color: AppColors.ink500)),
                          Text('1820', style: style(size: 20, weight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Вода', style: style(size: 12, weight: FontWeight.w600, color: AppColors.ink500)),
                          Text('1.6 л', style: style(size: 20, weight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: Text('Начать тренировку', style: style(size: 15, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Быстрая рыжая лиса прыгает через ленивую собаку — АБВГДабвгд 0123456789',
                style: style(size: 13, weight: FontWeight.w500, color: AppColors.ink500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
