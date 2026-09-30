import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: _sent ? _buildSentState(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Восстановление пароля', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Пришлём ссылку для сброса пароля на почту',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(label: 'Email', controller: _email, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(
          onPressed: () => setState(() => _sent = true),
          child: const Text('Отправить ссылку'),
        ),
      ],
    );
  }

  Widget _buildSentState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mark_email_read_rounded, color: AppColors.green500, size: 64),
        const SizedBox(height: AppSpacing.lg),
        Text('Проверьте почту', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Мы отправили инструкцию по восстановлению пароля на ${_email.text.isEmpty ? 'вашу почту' : _email.text}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Вернуться ко входу')),
      ],
    );
  }
}
