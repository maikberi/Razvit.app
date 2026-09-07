import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/mock/mock_nutrition.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/repositories/nutrition_repository.dart';
import 'add_food_screen.dart' show BarcodeSheet;
import 'food_ui.dart';

/// Открывает выбор способа добавления еды: из базы, штрихкод, фото (AI)
/// или вручную.
void showAddFoodMethodSheet(BuildContext context, MealType type) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AddFoodMethodSheet(type: type),
  );
}

class _AddFoodMethodSheet extends ConsumerWidget {
  const _AddFoodMethodSheet({required this.type});
  final MealType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Добавить в «${type.label.toLowerCase()}»', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            _MethodTile(
              icon: Icons.search_rounded,
              color: AppColors.green600,
              background: AppColors.green50,
              title: 'Выбрать из базы',
              subtitle: 'Поиск среди тысяч продуктов',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/add-food/${type.name}');
              },
            ),
            const SizedBox(height: 10),
            _MethodTile(
              icon: Icons.qr_code_scanner_rounded,
              color: const Color(0xFF3B82F6),
              background: const Color(0xFFEAF1FE),
              title: 'Сканировать штрихкод',
              subtitle: 'Найдём по базе Open Food Facts',
              onTap: () {
                Navigator.of(context).pop();
                _showBarcode(context, ref, type);
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
                _showPhotoAi(context, ref, type);
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
                _showManualEntry(context, ref, type);
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _showBarcode(BuildContext context, WidgetRef ref, MealType type) {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => BarcodeSheet(
      controller: controller,
      onAdd: (food, grams) {
        Navigator.of(sheetContext).pop();
        ref.read(mealsProvider.notifier).addFood(type, food, grams);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${food.name} добавлено')));
      },
    ),
  );
}

void _showPhotoAi(BuildContext context, WidgetRef ref, MealType type) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _PhotoAiSheet(
      onAdd: (food, grams) {
        Navigator.of(sheetContext).pop();
        ref.read(mealsProvider.notifier).addFood(type, food, grams);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${food.name} добавлено')));
      },
    ),
  );
}

void _showManualEntry(BuildContext context, WidgetRef ref, MealType type) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ManualEntrySheet(
      onAdd: (food, grams) {
        Navigator.of(sheetContext).pop();
        ref.read(mealsProvider.notifier).addFood(type, food, grams);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${food.name} добавлено')));
      },
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

class _PhotoAiSheet extends StatefulWidget {
  const _PhotoAiSheet({required this.onAdd});
  final void Function(FoodItem food, int grams) onAdd;

  @override
  State<_PhotoAiSheet> createState() => _PhotoAiSheetState();
}

enum _PhotoAiStage { idle, analyzing, result }

class _PhotoAiSheetState extends State<_PhotoAiSheet> {
  _PhotoAiStage _stage = _PhotoAiStage.idle;
  FoodItem? _recognized;
  int _grams = 100;

  Future<void> _takePhoto() async {
    setState(() => _stage = _PhotoAiStage.analyzing);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final food = mockFoods[Random().nextInt(mockFoods.length)];
    setState(() {
      _recognized = food;
      _grams = food.defaultGrams;
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
                _PhotoAiStage.result => Icon(Icons.restaurant_rounded, color: foodBadgeColor(_recognized!.id), size: 56),
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
                Text('${(_recognized!.caloriesPer100g * _grams / 100).round()} ккал', style: Theme.of(context).textTheme.titleMedium),
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
              child: ElevatedButton(onPressed: () => widget.onAdd(_recognized!, _grams), child: const Text('Добавить продукт')),
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
  final void Function(FoodItem food, int grams) onAdd;

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
    final food = FoodItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim(),
      caloriesPer100g: (calories * ratio).round(),
      proteinPer100g: (double.tryParse(_protein.text) ?? 0) * ratio,
      fatPer100g: (double.tryParse(_fat.text) ?? 0) * ratio,
      carbsPer100g: (double.tryParse(_carbs.text) ?? 0) * ratio,
      defaultGrams: grams,
    );
    widget.onAdd(food, grams);
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
