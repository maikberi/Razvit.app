import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/food_recognition.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/services/food_recognition_service.dart';
import '../../../data/services/nutrition_api_service.dart';
import 'food_ui.dart';
import 'nutrition_screen.dart' show AddFoodRow;
import 'recipe_ingredient_picker_screen.dart';

enum _ScanStage { idle, analyzing, error, results }

/// Экран "Scan Food" — AI Food Recognition. Архитектура (см. постановку
/// задачи): камера/галерея -> сжатое фото -> backend -> Vision AI называет
/// продукты и оценивает вес -> backend сопоставляет с Food Database и
/// считает КБЖУ через Nutrition Engine -> пользователь проверяет и
/// подтверждает -> сохранение в приём пищи. AI никогда не является
/// источником истины для КБЖУ — если продукт не нашёлся в базе, карточка
/// требует ручного выбора продукта, прежде чем её можно подтвердить.
class ScanFoodScreen extends ConsumerStatefulWidget {
  const ScanFoodScreen({super.key, required this.onConfirm});

  /// Вызывается один раз со списком подтверждённых (обязательно уже
  /// сопоставленных с базой) позиций — экран сам закрывается после.
  final Future<void> Function(List<RecognizedFoodItem> items) onConfirm;

  @override
  ConsumerState<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends ConsumerState<ScanFoodScreen> {
  _ScanStage _stage = _ScanStage.idle;
  Uint8List? _previewBytes;
  List<RecognizedFoodItem> _items = [];
  String? _notes;
  String? _errorMessage;
  bool _confirming = false;

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stage = _ScanStage.error;
        _errorMessage = source == ImageSource.camera
            ? 'Нет доступа к камере. Разреши доступ в настройках и попробуй снова.'
            : 'Не удалось открыть галерею.';
      });
      return;
    }
    if (file == null) return; // пользователь отменил выбор — остаёмся как есть

    final bytes = await file.readAsBytes();
    final mimeType = _detectMimeType(file);

    setState(() {
      _stage = _ScanStage.analyzing;
      _previewBytes = bytes;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(foodRecognitionServiceProvider).scan(bytes, mimeType);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _notes = result.notes;
        _stage = _ScanStage.results;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _ScanStage.error;
        _errorMessage = _messageFor(e);
      });
    }
  }

  String _detectMimeType(XFile file) {
    final mime = file.mimeType;
    if (mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp') return mime!;
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _messageFor(ApiException e) {
    if (e.isNetworkError) return 'Нет соединения с сервером. Проверь интернет и попробуй снова.';
    return switch (e.code) {
      'AI_NOT_CONFIGURED' => 'Распознавание фото пока недоступно.',
      'AI_TIMEOUT' => 'Анализ фото занял слишком много времени. Попробуй ещё раз.',
      'AI_RATE_LIMITED' => 'Слишком много запросов на распознавание. Попробуй через минуту.',
      'AI_UNAVAILABLE' => 'Сервис распознавания временно недоступен. Попробуй позже.',
      'INVALID_IMAGE' => 'Не удалось обработать это фото. Попробуй другое.',
      _ => e.message,
    };
  }

  void _retry() {
    setState(() {
      _stage = _ScanStage.idle;
      _previewBytes = null;
      _items = [];
      _errorMessage = null;
    });
  }

  /// Живой пересчёт КБЖУ через тот же чистый расчётный эндпоинт backend'а,
  /// что и остальные экраны добавления продукта (POST
  /// /nutrition/calculate/food) — Flutter здесь ничего сам не считает.
  /// Молча игнорирует ошибку: превью просто не покажется, но подтвердить
  /// и сохранить всё равно можно (при сохранении посчитает сам backend).
  Future<void> _recalculate(int index) async {
    final item = _items[index];
    if (!item.isMatched) return;
    final requestedGrams = item.estimatedGrams;
    try {
      final preview = await ref.read(nutritionApiServiceProvider).calculateFood(foodId: item.matchedFoodId!, grams: requestedGrams);
      if (!mounted || index >= _items.length || _items[index].estimatedGrams != requestedGrams) return; // ответ устарел
      setState(() {
        _items[index] = _items[index].withNutrition(
          RecognizedNutrition(calories: preview.calories, protein: preview.protein, fat: preview.fat, carbohydrates: preview.carbohydrates),
        );
      });
    } on ApiException {
      // тихо
    }
  }

  Future<void> _resolveItem(int index) async {
    final food = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(builder: (_) => const RecipeIngredientPickerScreen()),
    );
    if (food == null) return;
    setState(() {
      _items[index] = _items[index].withManualMatch(
        foodId: food.id,
        foodName: food.name,
        foodImageUrl: food.imageUrl,
        foodEmoji: food.emoji,
        basisUnit: food.basisUnit == FoodBasisUnit.milliliters ? 'ml' : 'g',
      );
    });
    unawaited(_recalculate(index));
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  Future<void> _addAnother() async {
    final food = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(builder: (_) => const RecipeIngredientPickerScreen()),
    );
    if (food == null) return;
    setState(() {
      _items.add(
        RecognizedFoodItem(
          aiName: food.name,
          estimatedGrams: food.defaultGrams.toDouble(),
          confidence: 1,
          possibleAlternatives: const [],
          uncertainty: null,
          matchedFoodId: food.id,
          matchedFoodName: food.name,
          matchedFoodImageUrl: food.imageUrl,
          matchedFoodEmoji: food.emoji,
          matchedBasisUnit: food.basisUnit == FoodBasisUnit.milliliters ? 'ml' : 'g',
          matchTier: 'exact',
          matchScore: 1,
          needsConfirmation: false,
          nutrition: null,
        ),
      );
    });
    unawaited(_recalculate(_items.length - 1));
  }

  bool get _allMatched => _items.isNotEmpty && _items.every((i) => i.isMatched);

  Future<void> _confirm() async {
    if (!_allMatched || _confirming) return;
    setState(() => _confirming = true);
    try {
      await widget.onConfirm(_items);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сканировать еду'), leading: const BackButton()),
      body: SafeArea(
        child: switch (_stage) {
          _ScanStage.idle => _IdleView(onPick: _pick),
          _ScanStage.analyzing => _AnalyzingView(previewBytes: _previewBytes),
          _ScanStage.error => _ErrorView(message: _errorMessage ?? 'Что-то пошло не так', onRetry: _retry),
          _ScanStage.results => _ResultsView(
              items: _items,
              notes: _notes,
              previewBytes: _previewBytes,
              allMatched: _allMatched,
              confirming: _confirming,
              onResolve: _resolveItem,
              onRemove: _removeItem,
              onGramsChanged: (i, grams) {
                setState(() => _items[i] = _items[i].withGrams(grams));
                unawaited(_recalculate(i));
              },
              onAddAnother: _addAnother,
              onRetake: _retry,
              onConfirm: _confirm,
            ),
        },
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onPick});
  final void Function(ImageSource source) onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(color: AppColors.green50, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt_rounded, size: 44, color: AppColors.green500),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Сфотографируй еду', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'AI распознает продукты на фото и предложит добавить их в дневник — калории и БЖУ посчитаются по реальным данным из базы',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => onPick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Сделать фото'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => onPick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Выбрать из галереи'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView({required this.previewBytes});
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (previewBytes != null)
          Opacity(
            opacity: 0.5,
            child: AspectRatio(aspectRatio: 4 / 3, child: Image.memory(previewBytes!, fit: BoxFit.cover)),
          ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text('AI анализирует фото…', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.ink400),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(onPressed: onRetry, child: const Text('Попробовать снова')),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.items,
    required this.notes,
    required this.previewBytes,
    required this.allMatched,
    required this.confirming,
    required this.onResolve,
    required this.onRemove,
    required this.onGramsChanged,
    required this.onAddAnother,
    required this.onRetake,
    required this.onConfirm,
  });

  final List<RecognizedFoodItem> items;
  final String? notes;
  final Uint8List? previewBytes;
  final bool allMatched;
  final bool confirming;
  final void Function(int index) onResolve;
  final void Function(int index) onRemove;
  final void Function(int index, double grams) onGramsChanged;
  final VoidCallback onAddAnother;
  final VoidCallback onRetake;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: AppSpacing.md),
            Text('Не получилось найти еду на фото', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Попробуй сфотографировать ближе, при более ярком свете, или добавь продукт вручную',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onRetake, child: const Text('Сделать другое фото')),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: onAddAnother, child: const Text('Добавить продукт вручную')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            children: [
              if (notes != null && notes!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.ink100, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.ink500),
                      const SizedBox(width: 8),
                      Expanded(child: Text(notes!, style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              for (var i = 0; i < items.length; i++) ...[
                _RecognizedItemCard(
                  item: items[i],
                  onResolve: () => onResolve(i),
                  onRemove: () => onRemove(i),
                  onGramsChanged: (g) => onGramsChanged(i, g),
                ),
                const SizedBox(height: 10),
              ],
              GestureDetector(
                onTap: onAddAnother,
                child: const AddFoodRow(label: 'Добавить ещё продукт'),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: Column(
              children: [
                if (!allMatched)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Выбери продукт из базы для каждой позиции, чтобы сохранить',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: allMatched && !confirming ? onConfirm : null,
                    child: confirming
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text('Подтвердить и добавить (${items.length})'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecognizedItemCard extends StatelessWidget {
  const _RecognizedItemCard({
    required this.item,
    required this.onResolve,
    required this.onRemove,
    required this.onGramsChanged,
  });

  final RecognizedFoodItem item;
  final VoidCallback onResolve;
  final VoidCallback onRemove;
  final ValueChanged<double> onGramsChanged;

  @override
  Widget build(BuildContext context) {
    final unit = item.matchedBasisUnit == 'ml' ? 'мл' : 'г';
    final grams = item.estimatedGrams;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FoodThumbnail(
                id: item.matchedFoodId ?? item.aiName,
                imageUrl: item.matchedFoodImageUrl,
                emoji: item.matchedFoodEmoji,
                size: 40,
                iconSize: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.matchedFoodName ?? item.aiName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.isMatched && item.needsConfirmation)
                      Text('Похоже, но не точно — проверь продукт', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning)),
                  ],
                ),
              ),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded, color: AppColors.ink400), visualDensity: VisualDensity.compact),
            ],
          ),
          if (item.uncertainty != null) ...[
            const SizedBox(height: 4),
            Text(item.uncertainty!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500, fontStyle: FontStyle.italic)),
          ],
          if (item.possibleAlternatives.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Может быть: ${item.possibleAlternatives.join(", ")}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.ink500)),
          ],
          const SizedBox(height: 10),
          if (!item.isMatched)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Не найден в базе — выбрать продукт'),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: grams > 10 ? () => onGramsChanged(grams - 10) : null,
                  icon: const Icon(Icons.remove_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
                ),
                SizedBox(
                  width: 90,
                  child: Text('${grams.round()} $unit', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton.filled(
                  onPressed: () => onGramsChanged(grams + 10),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
                ),
                const Spacer(),
                TextButton(onPressed: onResolve, child: const Text('Изменить продукт')),
              ],
            ),
            if (item.nutrition != null) ...[
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: _stat(context, 'Калории', '${item.nutrition!.calories}')),
                  Expanded(child: _stat(context, 'Белки', '${item.nutrition!.protein.toStringAsFixed(1)} г')),
                  Expanded(child: _stat(context, 'Жиры', '${item.nutrition!.fat.toStringAsFixed(1)} г')),
                  Expanded(child: _stat(context, 'Углеводы', '${item.nutrition!.carbohydrates.toStringAsFixed(1)} г')),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
