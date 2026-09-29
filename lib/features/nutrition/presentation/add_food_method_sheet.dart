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
import 'scan_food_screen.dart';

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
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ScanFoodScreen(
        onConfirm: (items) async {
          for (final item in items) {
            await _completeAdd(context, mealId, foodId: item.matchedFoodId, name: item.matchedFoodName, grams: item.estimatedGrams.round());
          }
        },
      ),
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
  // Пустые контроллеры вместо реального текста '0' — раньше поля БЖУ
  // были предзаполнены значением "0", и чтобы ввести своё число,
  // приходилось сначала стирать этот "0" вручную. Теперь "0" — это просто
  // hint (серая подсказка), она сама исчезает при вводе, как и положено
  // плейсхолдеру. При сохранении пустое поле по-прежнему считается нулём.
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();

  bool get _canSave => _name.text.trim().isNotEmpty && (int.tryParse(_grams.text) ?? 0) > 0 && (int.tryParse(_calories.text) ?? -1) >= 0;

  @override
  void dispose() {
    _name.dispose();
    _grams.dispose();
    _calories.dispose();
    _protein.dispose();
    _fat.dispose();
    _carbs.dispose();
    super.dispose();
  }

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
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFFFFF4DF), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: const Icon(Icons.edit_note_rounded, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Ввести вручную', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Название блюда', prefixIcon: Icon(Icons.restaurant_menu_rounded)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _grams,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Граммы', suffixText: 'г'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _calories,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.green700, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    labelText: 'Калории',
                    hintText: '0',
                    suffixText: 'ккал',
                    prefixIcon: Icon(Icons.local_fire_department_rounded, color: AppColors.green600),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('БЖУ на этот вес', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.ink500)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _MacroField(controller: _protein, label: 'Белки', color: AppColors.protein)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _MacroField(controller: _fat, label: 'Жиры', color: AppColors.fat)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _MacroField(controller: _carbs, label: 'Углеводы', color: AppColors.carbs)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canSave ? _save : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить продукт'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Поле одного макронутриента (Б/Ж/У) — цветная метка над полем вместо
/// плавающего labelText, компактнее в тесной строке из трёх полей.
class _MacroField extends StatelessWidget {
  const _MacroField({required this.controller, required this.label, required this.color});
  final TextEditingController controller;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink500)),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(hintText: '0', suffixText: 'г', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14)),
        ),
      ],
    );
  }
}
