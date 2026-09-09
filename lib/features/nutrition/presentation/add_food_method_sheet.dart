import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_day_repository.dart';
import '../../../data/services/nutrition_api_service.dart';
import 'barcode_scanner_screen.dart';
import 'food_ui.dart';

/// Открывает выбор способа добавления еды: из базы, штрихкод, фото (AI)
/// или вручную — в конкретный приём пищи [mealId] (реальный id с backend).
void showAddFoodMethodSheet(BuildContext context, {required String mealId, required MealType mealType}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AddFoodMethodSheet(mealId: mealId, mealType: mealType),
  );
}

class _AddFoodMethodSheet extends StatelessWidget {
  const _AddFoodMethodSheet({required this.mealId, required this.mealType});
  final String mealId;
  final MealType mealType;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Добавить в «${mealType.label.toLowerCase()}»', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            _MethodTile(
              icon: Icons.search_rounded,
              color: AppColors.green600,
              background: AppColors.green50,
              title: 'Выбрать из базы',
              subtitle: 'Поиск среди тысяч продуктов',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/add-food?mealId=$mealId&mealType=${mealType.name}');
              },
            ),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.qr_code_scanner_rounded,
              color: const Color(0xFF3B82F6),
              background: const Color(0xFFEAF1FE),
              title: 'Сканировать штрихкод',
              subtitle: 'Найдём в базе продуктов RAZVIT',
              onTap: () {
                Navigator.of(context).pop();
                _showBarcode(context, mealId);
              },
            ),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF8B5CF6),
              background: const Color(0xFFF2ECFE),
              title: 'Сфотографировать блюдо',
              subtitle: 'AI распознает и посчитает калории',
              onTap: () {
                Navigator.of(context).pop();
                _showPhotoAi(context, mealId);
              },
            ),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.edit_note_rounded,
              color: const Color(0xFFF59E0B),
              background: const Color(0xFFFFF4DF),
              title: 'Ввести вручную',
              subtitle: 'Свои граммы, калории и БЖУ',
              onTap: () {
                Navigator.of(context).pop();
                _showManualEntry(context, mealId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Добавляет продукт в приём пищи через реальный backend и обновляет день.
/// [sheetContext] — контекст ТЕКУЩЕГО (открытого сейчас) шита, а не
/// исходного, который открыл цепочку шитов — только он гарантированно
/// смонтирован в момент вызова (см. урок про устаревший WidgetRef выше
/// по истории проекта: нельзя использовать context уже закрытого шита
/// после await).
Future<void> _addFoodFromSheet(
  BuildContext sheetContext,
  String mealId, {
  String? foodId,
  String? name,
  ManualNutrients? nutrients,
  required int grams,
}) async {
  Navigator.of(sheetContext).pop();
  await _completeAdd(sheetContext, mealId, foodId: foodId, name: name, nutrients: nutrients, grams: grams);
}

/// То же самое, но без попытки закрыть шит — для потока сканера
/// штрихкода (BarcodeScannerScreen сам закрывает и результат, и себя
/// ДО вызова onAdd, поэтому здесь закрывать уже нечего).
Future<void> _completeAdd(
  BuildContext context,
  String mealId, {
  String? foodId,
  String? name,
  ManualNutrients? nutrients,
  required int grams,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await container.read(nutritionDayProvider.notifier).addFoodItem(
          mealId: mealId,
          foodId: foodId,
          name: name,
          nutrients: nutrients,
          grams: grams.toDouble(),
        );
    messenger.showSnackBar(SnackBar(content: Text('${name ?? "Продукт"} добавлено')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
  }
}

/// Публичные точки входа для "Быстрого добавления" на Nutrition Home
/// Screen — открывают конкретный способ добавления напрямую, минуя шит
/// выбора способа (он уже выбран нажатием соответствующей кнопки).
void openBarcodeLookup(BuildContext context, String mealId) => _showBarcode(context, mealId);
void openPhotoAi(BuildContext context, String mealId) => _showPhotoAi(context, mealId);
void openManualEntry(BuildContext context, String mealId) => _showManualEntry(context, mealId);

void _showBarcode(BuildContext context, String mealId) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BarcodeScannerScreen(
        onAdd: (food, grams) => _completeAdd(context, mealId, foodId: food.id, name: food.name, grams: grams),
      ),
    ),
  );
}

void _showPhotoAi(BuildContext context, String mealId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _PhotoAiSheet(
      onAdd: (name, nutrients, grams) => _addFoodFromSheet(sheetContext, mealId, name: name, nutrients: nutrients, grams: grams),
    ),
  );
}

void _showManualEntry(BuildContext context, String mealId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ManualEntrySheet(
      onAdd: (name, nutrients, grams) => _addFoodFromSheet(sheetContext, mealId, name: name, nutrients: nutrients, grams: grams),
    ),
  );
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
        ],
      ),
    );
  }
}

/// Мок-"распознавание" блюда по фото — реального AI ещё нет (нужен
/// отдельный внешний сервис компьютерного зрения на backend). Но
/// результат добавляется в приём пищи по-настоящему: как ручная запись
/// с распознанным названием и оценёнными нутриентами.
const _mockRecognitionCandidates = [
  (name: 'Овсянка с фруктами', calories: 120.0, protein: 4.0, fat: 3.0, carbs: 20.0, grams: 250),
  (name: 'Куриная грудка с овощами', calories: 140.0, protein: 20.0, fat: 4.0, carbs: 5.0, grams: 300),
  (name: 'Салат Цезарь', calories: 190.0, protein: 8.0, fat: 15.0, carbs: 6.0, grams: 220),
  (name: 'Паста Болоньезе', calories: 160.0, protein: 7.0, fat: 5.0, carbs: 22.0, grams: 280),
];

class _PhotoAiSheet extends StatefulWidget {
  const _PhotoAiSheet({required this.onAdd});
  final void Function(String name, ManualNutrients nutrients, int grams) onAdd;

  @override
  State<_PhotoAiSheet> createState() => _PhotoAiSheetState();
}

enum _PhotoAiStage { idle, analyzing, result }

class _PhotoAiSheetState extends State<_PhotoAiSheet> {
  _PhotoAiStage _stage = _PhotoAiStage.idle;
  ({String name, double calories, double protein, double fat, double carbs, int grams})? _recognized;
  int _grams = 100;

  Future<void> _takePhoto() async {
    setState(() => _stage = _PhotoAiStage.analyzing);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final result = _mockRecognitionCandidates[Random().nextInt(_mockRecognitionCandidates.length)];
    setState(() {
      _recognized = result;
      _grams = result.grams;
      _stage = _PhotoAiStage.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Фото блюда', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          AspectRatio(
            aspectRatio: 1.4,
            child: Container(
              decoration: BoxDecoration(color: AppColors.ink900, borderRadius: BorderRadius.circular(AppRadius.lg)),
              alignment: Alignment.center,
              child: switch (_stage) {
                _PhotoAiStage.idle => const Icon(Icons.camera_alt_rounded, color: Colors.white38, size: 56),
                _PhotoAiStage.analyzing => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
                      SizedBox(height: AppSpacing.sm),
                      Text('AI анализирует фото...', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                _PhotoAiStage.result => Icon(Icons.restaurant_rounded, color: foodBadgeColor(_recognized!.name), size: 56),
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_stage == _PhotoAiStage.idle) ...[
            Text(
              'Сфотографируй блюдо — RAZVIT распознает продукт и посчитает калорийность',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt_rounded), label: const Text('Сделать фото')),
            ),
          ],
          if (_stage == _PhotoAiStage.result) ...[
            Row(
              children: [
                Expanded(
                  child: Text('Похоже на «${_recognized!.name}»', style: Theme.of(context).textTheme.titleMedium),
                ),
                Text('${(_recognized!.calories * _grams / 100).round()} ккал', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: _grams > 10 ? () => setState(() => _grams -= 10) : null,
                  icon: const Icon(Icons.remove_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
                ),
                SizedBox(width: 100, child: Text('$_grams г', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
                IconButton.filled(
                  onPressed: () => setState(() => _grams += 10),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onAdd(
                  _recognized!.name,
                  ManualNutrients(calories: _recognized!.calories, protein: _recognized!.protein, fat: _recognized!.fat, carbohydrates: _recognized!.carbs),
                  _grams,
                ),
                child: const Text('Добавить продукт'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(onPressed: _takePhoto, child: const Text('Это не то — переснять')),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet({required this.onAdd});
  final void Function(String name, ManualNutrients nutrients, int grams) onAdd;

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _name = TextEditingController();
  final _grams = TextEditingController(text: '100');
  final _calories = TextEditingController();
  final _protein = TextEditingController(text: '0');
  final _fat = TextEditingController(text: '0');
  final _carbs = TextEditingController(text: '0');

  bool get _canSave => _name.text.trim().isNotEmpty && (int.tryParse(_grams.text) ?? 0) > 0 && (int.tryParse(_calories.text) ?? -1) >= 0;

  void _save() {
    final grams = int.parse(_grams.text);
    final calories = int.parse(_calories.text);
    final ratio = 100 / grams;
    final nutrients = ManualNutrients(
      calories: calories * ratio,
      protein: (double.tryParse(_protein.text) ?? 0) * ratio,
      fat: (double.tryParse(_fat.text) ?? 0) * ratio,
      carbohydrates: (double.tryParse(_carbs.text) ?? 0) * ratio,
    );
    widget.onAdd(_name.text.trim(), nutrients, grams);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ввести вручную', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Название блюда'), onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _grams,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Граммы'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _calories,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Калории'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: TextField(controller: _protein, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Белки, г'))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: TextField(controller: _fat, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Жиры, г'))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: TextField(controller: _carbs, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Углеводы, г'))),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _canSave ? _save : null, child: const Text('Добавить продукт')),
          ),
        ],
      ),
    );
  }
}
