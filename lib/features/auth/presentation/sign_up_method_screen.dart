import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/google_auth_gateway.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../data/repositories/user_repository.dart';

enum _MockAuthProvider { apple, telegram, vk }

class SignUpMethodScreen extends ConsumerStatefulWidget {
  const SignUpMethodScreen({super.key});

  @override
  ConsumerState<SignUpMethodScreen> createState() => _SignUpMethodScreenState();
}

class _SignUpMethodScreenState extends ConsumerState<SignUpMethodScreen> {
  Object? _loading; // _MockAuthProvider или 'google', пока идёт соответствующий вход

  /// Google — настоящий вход: получаем id-токен от Google, backend сам
  /// проверяет его и создаёт/находит пользователя (см. AuthNotifier.loginWithGoogle).
  Future<void> _continueWithGoogle() async {
    setState(() => _loading = 'google');
    try {
      final idToken = await GoogleAuthGateway.signInAndGetIdToken();
      if (idToken == null) return; // пользователь закрыл окно выбора аккаунта — не ошибка
      final isNewUser = await ref.read(authProvider.notifier).loginWithGoogle(idToken);
      if (!mounted) return;
      if (isNewUser) {
        context.push('/onboarding');
      } else {
        ref.read(onboardingCompletedProvider.notifier).complete();
        context.go('/home');
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } on StateError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  /// Apple/Telegram/VK: реального OAuth с ними пока нет (см. TODO в
  /// AuthNotifier.signInLocalOnly) — сессия локальная, не переживёт перезапуск.
  Future<void> _continueWithMock(_MockAuthProvider provider) async {
    setState(() => _loading = provider);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = null);
    final name = switch (provider) {
      _MockAuthProvider.apple => 'Гость Apple',
      _MockAuthProvider.telegram => 'Гость Telegram',
      _MockAuthProvider.vk => 'Гость VK',
    };
    ref.read(userProvider.notifier).updateProfile(name: name);
    ref.read(authProvider.notifier).signInLocalOnly();
    context.push('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                child: Text(
                  'Добро пожаловать!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
                ),
              ),
              const SizedBox(height: 10),
              FadeSlideIn(
                delay: const Duration(milliseconds: 40),
                child: Container(width: 28, height: 4, decoration: BoxDecoration(color: AppColors.green500, borderRadius: BorderRadius.circular(AppRadius.pill))),
              ),
              const SizedBox(height: AppSpacing.md),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Text('Выберите удобный\nспособ входа', style: Theme.of(context).textTheme.headlineLarge),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _ProviderButton(
                  label: 'Продолжить с Google',
                  loading: _loading == 'google',
                  onTap: _continueWithGoogle,
                  background: Colors.white,
                  foreground: Colors.black87,
                  bordered: true,
                  logo: SvgPicture.asset('assets/logo/Group.svg', width: 26, height: 26, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: _ProviderButton(
                  label: 'Войти через VK',
                  loading: _loading == _MockAuthProvider.vk,
                  onTap: () => _continueWithMock(_MockAuthProvider.vk),
                  logo: SvgPicture.asset('assets/logo/VK.svg', width: 26, height: 26, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _ProviderButton(
                  label: 'Войти через Telegram',
                  loading: _loading == _MockAuthProvider.telegram,
                  onTap: () => _continueWithMock(_MockAuthProvider.telegram),
                  logo: SvgPicture.asset('assets/logo/TG.svg', width: 26, height: 26, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FadeSlideIn(
                delay: const Duration(milliseconds: 350),
                child: _ProviderButton(
                  label: 'Продолжить с Apple',
                  loading: _loading == _MockAuthProvider.apple,
                  onTap: () => _continueWithMock(_MockAuthProvider.apple),
                  background: Colors.black,
                  foreground: Colors.white,
                  logo: SvgPicture.asset('assets/logo/Vector.svg', width: 26, height: 26, fit: BoxFit.contain, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Text('или', style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeSlideIn(
                delay: const Duration(milliseconds: 450),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/register'),
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('Войти по email'),
                  ),
                ),
              ),
              const Spacer(),
              FadeSlideIn(
                delay: const Duration(milliseconds: 500),
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
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.logo,
    required this.onTap,
    required this.loading,
    this.background,
    this.foreground,
    this.bordered = false,
  });

  final String label;
  final Widget logo;
  final VoidCallback onTap;
  final bool loading;
  final Color? background;
  final Color? foreground;

  /// Тонкая рамка нужна только фирменным светлым кнопкам (Google) — чтобы
  /// не сливаться с тёмным фоном. VK/Telegram — плоская вторичная
  /// поверхность (цвет карточки темы) без рамки, как в макете.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? Theme.of(context).cardTheme.color;
    final fg = foreground ?? Theme.of(context).textTheme.bodyLarge?.color;
    return PressableScale(
      onTap: loading ? () {} : onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: bordered ? Border.all(color: Theme.of(context).dividerColor) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (loading)
              SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
            else ...[
              // Единый размер бокса под лого — иконки провайдеров разного
              // "родного" соотношения сторон визуально выглядят одинаково.
              SizedBox(width: 26, height: 26, child: Center(child: logo)),
              const SizedBox(width: 16),
              Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: fg)),
            ],
          ],
        ),
      ),
    );
  }
}
