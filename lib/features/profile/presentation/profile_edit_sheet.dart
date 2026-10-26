import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/avatar.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/auth_api_service.dart';

const _maxAvatarBytes = 480 * 1024;

/// Настоящее редактирование профиля (имя, фамилия, никнейм, фото) — раньше
/// "Личные данные" были только для чтения, а всё, что можно было изменить,
/// жило в памяти вкладки и пропадало при перезапуске. Сохранение идёт через
/// PATCH /auth/me и сразу обновляет userProvider результатом с backend.
void showProfileEditSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ProfileEditSheet(),
  );
}

class _ProfileEditSheet extends ConsumerStatefulWidget {
  const _ProfileEditSheet();

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _lastName;
  late final TextEditingController _nickname;
  String? _avatarDataUrl;
  bool _avatarRemoved = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _name = TextEditingController(text: user.name);
    _lastName = TextEditingController(text: user.lastName ?? '');
    _nickname = TextEditingController(text: user.nickname ?? '');
    _avatarDataUrl = user.avatarUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 75);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = source == ImageSource.camera ? 'Нет доступа к камере.' : 'Не удалось открыть галерею.');
      return;
    }
    if (file == null) return;

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.length > _maxAvatarBytes) {
      if (!mounted) return;
      setState(() => _error = 'Фото слишком большое — выбери другое или сделай новый снимок.');
      return;
    }

    final mime = file.mimeType ?? 'image/jpeg';
    if (!mounted) return;
    setState(() {
      _avatarDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      _avatarRemoved = false;
      _error = null;
    });
  }

  void _showAvatarSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.green600),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.green600),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAvatar(ImageSource.gallery);
              },
            ),
            if (_avatarDataUrl != null && !_avatarRemoved)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Удалить фото', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _avatarDataUrl = null;
                    _avatarRemoved = true;
                  });
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Имя не может быть пустым');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final lastName = _lastName.text.trim();
      final nickname = _nickname.text.trim();
      final updated = await ref.read(authApiServiceProvider).updateProfile(
            name: name,
            lastName: lastName.isEmpty ? null : lastName,
            nickname: nickname.isEmpty ? null : nickname,
            avatarUrl: _avatarRemoved ? null : _avatarDataUrl,
          );
      ref.read(userProvider.notifier).setFromAuth(updated);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(color: AppColors.ink200, borderRadius: BorderRadius.circular(AppRadius.pill)),
              ),
            ),
            Text('Личные данные', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: GestureDetector(
                onTap: _showAvatarSourceSheet,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(name: _name.text.isEmpty ? user.name : _name.text, size: 96, imageUrl: _avatarDataUrl),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.green500,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(onPressed: _showAvatarSourceSheet, child: const Text('Изменить фото')),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Имя', prefixIcon: Icon(Icons.badge_outlined)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Фамилия', prefixIcon: Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nickname,
              decoration: const InputDecoration(labelText: 'Никнейм', prefixIcon: Icon(Icons.alternate_email_rounded)),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              enabled: false,
              controller: TextEditingController(text: user.email),
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
