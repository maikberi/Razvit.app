import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/social_redirect_gateway.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/user_repository.dart';

/// Экран-приёмник редиректа VK ID (см. core/auth/social_redirect_gateway.dart).
/// VK возвращает пользователя сюда с параметрами `code`/`device_id`/`state`
/// в query (плюс `codeVerifier`, который туда уже подставил
/// SocialRedirectGateway.vkCallbackInitialRoute из sessionStorage) — здесь
/// мы сразу меняем их на сессию через backend и уходим дальше, ничего не
/// показывая, кроме индикатора загрузки.
class VkCallbackScreen extends ConsumerStatefulWidget {
  const VkCallbackScreen({
    super.key,
    required this.code,
    required this.deviceId,
    required this.codeVerifier,
    required this.state,
    required this.error,
  });

  final String? code;
  final String? deviceId;
  final String? codeVerifier;
  final String? state;
  final String? error;

  @override
  ConsumerState<VkCallbackScreen> createState() => _VkCallbackScreenState();
}

class _VkCallbackScreenState extends ConsumerState<VkCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  Future<void> _finish() async {
    final code = widget.code;
    final deviceId = widget.deviceId;
    final codeVerifier = widget.codeVerifier;
    final state = widget.state;
    if (widget.error != null || code == null || code.isEmpty || deviceId == null || codeVerifier == null || state == null) {
      _fail('Вход через VK отменён');
      return;
    }
    try {
      final isNewUser = await ref.read(authProvider.notifier).loginWithVk(
            code: code,
            deviceId: deviceId,
            codeVerifier: codeVerifier,
            redirectUri: SocialRedirectGateway.vkRedirectUri(),
            state: state,
          );
      if (!mounted) return;
      if (isNewUser) {
        context.go('/onboarding');
      } else {
        ref.read(onboardingCompletedProvider.notifier).complete();
        context.go('/home');
      }
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Не удалось подтвердить вход через VK');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
    context.go('/sign-up-method');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
