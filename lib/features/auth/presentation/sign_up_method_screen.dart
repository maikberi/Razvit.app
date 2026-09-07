import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/razvit_logo.dart';
import '../../../data/repositories/user_repository.dart';

enum _AuthProvider { google, apple, telegram, vk }

class SignUpMethodScreen extends ConsumerStatefulWidget {
  const SignUpMethodScreen({super.key});

  @override
  ConsumerState<SignUpMethodScreen> createState() => _SignUpMethodScreenState();
}

class _SignUpMethodScreenState extends ConsumerState<SignUpMethodScreen> {
  _AuthProvider? _loading;

  Future<void> _continueWith(_AuthProvider provider) async {
    setState(() => _loading = provider);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = null);
    final name = switch (provider) {
      _AuthProvider.google => 'Гость Google',
      _AuthProvider.apple => 'Гость Apple',
      _AuthProvider.telegram => 'Гость Telegram',
      _AuthProvider.vk => 'Гость VK',
    };
    ref.read(userProvider.notifier).updateProfile(name: name);
    ref.read(authProvider.notifier).signIn();
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
            children: [
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(child: const RazvitMark(size: 72)),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Text('Как хочешь зарегистрироваться?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              ),
              const SizedBox(height: AppSpacing.xs),
              FadeSlideIn(
                delay: const Duration(milliseconds: 140),
                child: Text(
                  'Выбери удобный способ входа',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _ProviderButton(
                  label: 'Продолжить с Google',
                  loading: _loading == _AuthProvider.google,
                  onTap: () => _continueWith(_AuthProvider.google),
                  logo: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    child: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: _ProviderButton(
                  label: 'Продолжить с Apple',
                  loading: _loading == _AuthProvider.apple,
                  onTap: () => _continueWith(_AuthProvider.apple),
                  background: Colors.black,
                  foreground: Colors.white,
                  logo: const Icon(Icons.apple_rounded, size: 22, color: Colors.white),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _ProviderButton(
                  label: 'Продолжить с Telegram',
                  loading: _loading == _AuthProvider.telegram,
                  onTap: () => _continueWith(_AuthProvider.telegram),
                  logo: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Color(0xFF29A9EA),
                    child: Icon(Icons.send_rounded, size: 13, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FadeSlideIn(
                delay: const Duration(milliseconds: 350),
                child: _ProviderButton(
                  label: 'Продолжить с VK',
                  loading: _loading == _AuthProvider.vk,
                  onTap: () => _continueWith(_AuthProvider.vk),
                  logo: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: const Color(0xFF0077FF), borderRadius: BorderRadius.circular(6)),
                    alignment: Alignment.center,
                    child: const Text('VK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
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
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/register'),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('Продолжить по почте'),
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
  });

  final String label;
  final Widget logo;
  final VoidCallback onTap;
  final bool loading;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? Theme.of(context).cardTheme.color;
    final fg = foreground ?? Theme.of(context).textTheme.bodyLarge?.color;
    return PressableScale(
      onTap: loading ? () {} : onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: background == null ? Border.all(color: Theme.of(context).dividerColor) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
            else ...[
              logo,
              const SizedBox(width: 12),
              Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: fg)),
            ],
          ],
        ),
      ),
    );
  }
}
