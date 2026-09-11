import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/services/food_service.dart';
import 'add_food_screen.dart' show BarcodeSheet, ProductDetailSheet;

/// Полноэкранный сканер штрихкода камерой — основной способ найти продукт
/// по штрихкоду (mobile_scanner: стабильный пакет, распознавание полностью
/// локально на устройстве/в браузере через getUserMedia, без AI и без
/// облачных сервисов — работает и в Flutter Web). На вебе пакет при первом
/// запуске подгружает JS-библиотеку распознавания (@zxing/library) с
/// unpkg.com — если сеть/CDN недоступны, инициализация камеры может
/// зависнуть без явной ошибки, поэтому ниже есть свой таймаут (см.
/// _startupTimeoutTimer) с откатом на ручной ввод.
///
/// Сам поиск продукта (RAZVIT → Open Food Facts → нормализация →
/// сохранение) уже делает backend (см. FoodSearchService.lookupBarcode на
/// backend, FoodService.lookupBarcode во Flutter) — этот экран только
/// подаёт туда распознанный код и показывает результат.
///
/// Ручной ввод (BarcodeSheet) — запасной вариант, всегда доступен кнопкой
/// "Вручную" и подставляется автоматически, если камера недоступна, доступ
/// к ней запрещён или её не удалось инициализировать за разумное время.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key, required this.onAdd});

  final void Function(FoodItem food, int grams) onAdd;

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

enum _LookupState { scanning, looking, notFound, error }

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  _LookupState _state = _LookupState.scanning;
  String? _errorMessage;
  bool _processing = false;
  bool _resultOpen = false;

  Timer? _startupTimeoutTimer;
  bool _startupTimedOut = false;

  @override
  void initState() {
    super.initState();
    // Если камера не проинициализировалась (и не выдала ошибку) за 8
    // секунд — считаем, что запуск завис (чаще всего из-за недоступности
    // внешнего CDN с библиотекой распознавания на вебе), и сразу
    // предлагаем ручной ввод вместо бесконечного чёрного экрана.
    _startupTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_controller.value.isInitialized) {
        setState(() => _startupTimedOut = true);
      }
    });
    _controller.addListener(_onControllerValueChanged);
  }

  void _onControllerValueChanged() {
    if (_controller.value.isInitialized || _controller.value.error != null) {
      _startupTimeoutTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _startupTimeoutTimer?.cancel();
    _controller.removeListener(_onControllerValueChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    _processing = true;
    await _controller.stop();
    if (!mounted) return;
    setState(() => _state = _LookupState.looking);

    try {
      final food = await ref.read(foodServiceProvider).lookupBarcode(code);
      if (!mounted) return;
      if (food == null) {
        setState(() => _state = _LookupState.notFound);
      } else {
        setState(() => _state = _LookupState.scanning);
        _showResult(food);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LookupState.error;
        _errorMessage = e.message;
      });
    }
  }

  void _showResult(FoodItem food) {
    _resultOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ProductDetailSheet(
        food: food,
        onAdd: (grams) {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).pop();
          widget.onAdd(food, grams);
        },
      ),
    ).whenComplete(() {
      _resultOpen = false;
      // Экран сканера мог уже закрыться (продукт добавлен) — тогда resume не нужен.
      if (mounted) _resumeScanning();
    });
  }

  void _resumeScanning() {
    _processing = false;
    setState(() {
      _state = _LookupState.scanning;
      _errorMessage = null;
    });
    unawaited(_controller.start());
  }

  void _openManualEntry() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => BarcodeSheet(
        controller: textController,
        onAdd: (food, grams) {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).pop();
          widget.onAdd(food, grams);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Сканировать штрихкод'),
        actions: [
          TextButton(
            onPressed: _openManualEntry,
            child: const Text('Вручную', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_startupTimedOut)
            _CameraTimeout(onManualEntry: _openManualEntry)
          else
            MobileScanner(
              controller: _controller,
              onDetect: _resultOpen ? (_) {} : _onDetect,
              errorBuilder: (context, error, child) => _CameraError(error: error, onManualEntry: _openManualEntry),
            ),
          if (!_startupTimedOut) const _ScanFrame(),
          if (_state == _LookupState.looking)
            const ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          if (_state == _LookupState.notFound)
            _StatusBanner(
              icon: Icons.search_off_rounded,
              message: 'Продукт с таким штрихкодом не найден',
              actionLabel: 'Ввести вручную',
              onAction: _openManualEntry,
              onDismiss: _resumeScanning,
            ),
          if (_state == _LookupState.error)
            _StatusBanner(
              icon: Icons.wifi_off_rounded,
              message: _errorMessage ?? 'Не удалось выполнить поиск',
              actionLabel: 'Повторить',
              onAction: _resumeScanning,
              onDismiss: _resumeScanning,
            ),
        ],
      ),
    );
  }
}

/// Просто рамка-подсказка "куда наводить" поверх превью камеры — сама
/// область распознавания не ограничена ей (mobile_scanner сканирует весь
/// кадр), это чисто визуальная подсказка пользователю.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white70, width: 2),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.ink500, size: 28),
              const SizedBox(height: AppSpacing.sm),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: onDismiss, child: const Text('Ещё раз'))),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: ElevatedButton(onPressed: onAction, child: Text(actionLabel))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Показывается вместо превью камеры, если её не удалось запустить —
/// нет разрешения, камеры нет на устройстве/у браузера нет доступа к ней,
/// либо она уже занята другим приложением/вкладкой.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onManualEntry});

  final MobileScannerException error;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
          Icons.no_photography_rounded,
          'Нет доступа к камере. Разрешите доступ в настройках браузера/устройства и попробуйте снова — либо введите штрихкод вручную.',
        ),
      MobileScannerErrorCode.unsupported => (
          Icons.videocam_off_rounded,
          'На этом устройстве нет доступной камеры — введите штрихкод вручную.',
        ),
      _ => (
          Icons.error_outline_rounded,
          'Не удалось запустить камеру — введите штрихкод вручную.',
        ),
    };
    return _CameraFallback(icon: icon, message: message, onManualEntry: onManualEntry);
  }
}

/// То же самое, что и явная ошибка камеры, но для случая, когда запуск
/// просто завис (не вернул ни картинку, ни ошибку) — см. _startupTimeoutTimer.
class _CameraTimeout extends StatelessWidget {
  const _CameraTimeout({required this.onManualEntry});

  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return _CameraFallback(
      icon: Icons.hourglass_disabled_rounded,
      message: 'Не получилось запустить камеру (слишком долго) — введите штрихкод вручную.',
      onManualEntry: onManualEntry,
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({required this.icon, required this.message, required this.onManualEntry});

  final IconData icon;
  final String message;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white54, size: 56),
              const SizedBox(height: AppSpacing.lg),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onManualEntry, child: const Text('Ввести вручную')),
            ],
          ),
        ),
      ),
    );
  }
}
