import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/mascot.dart';
import '../../../data/repositories/user_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _nicknameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    for (final node in [_firstNameFocus, _lastNameFocus, _nicknameFocus, _emailFocus, _passwordFocus]) {
      node.addListener(() => setState(() {}));
    }
    _firstName.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _nicknameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String get _mascotTip {
    final name = _firstName.text.trim();
    if (_passwordFocus.hasFocus) return 'Пароль от 8 символов — и никому его не показывай 🔒';
    if (_emailFocus.hasFocus) return 'Укажи почту, чтобы не потерять доступ к аккаунту.';
    if (_nicknameFocus.hasFocus) return 'Придумай никнейм — его увидят другие в приложении.';
    if (_lastNameFocus.hasFocus) return 'Фамилия — необязательно, но приятно!';
    if (_firstNameFocus.hasFocus) {
      return name.isEmpty ? 'Введи своё имя — так я буду к тебе обращаться!' : 'Приятно познакомиться, $name! 👋';
    }
    if (name.isNotEmpty) return 'Отлично, $name! Заполни остальные поля, и начнём 💪';
    return 'Привет! Я твой AI-ассистент. Давай знакомиться 👋';
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _loading = false);
    ref.read(userProvider.notifier).updateProfile(
          name: _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
          lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
          nickname: _nickname.text.trim().isEmpty ? null : _nickname.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        );
    ref.read(authProvider.notifier).signIn();
    context.push('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              MascotBubble(text: _mascotTip),
              const SizedBox(height: AppSpacing.lg),
              Text('Создать аккаунт', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Регистрация займёт меньше минуты',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(child: AppTextField(label: 'Имя', controller: _firstName, focusNode: _firstNameFocus, hint: 'Михаил')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: AppTextField(label: 'Фамилия', controller: _lastName, focusNode: _lastNameFocus, hint: 'Иванов')),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Никнейм', controller: _nickname, focusNode: _nicknameFocus, hint: '@mikhail'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Email', controller: _email, focusNode: _emailFocus, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Пароль',
                controller: _password,
                focusNode: _passwordFocus,
                hint: 'Минимум 8 символов',
                obscureText: _obscure,
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.ink400),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Зарегистрироваться'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Продолжая, вы соглашаетесь с условиями использования и политикой конфиденциальности RAZVIT.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
