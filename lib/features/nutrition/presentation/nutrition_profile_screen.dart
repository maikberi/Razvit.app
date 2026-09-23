import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/nutrition_profile.dart';
import '../../../data/repositories/nutrition_day_repository.dart';
import '../../../data/services/nutrition_api_service.dart';

/// Данные для Nutrition Target Service на backend: вес/рост/возраст/пол/
/// активность/цель -> расчёт персональных целей по калориям, БЖУ и воде
/// (BMR/TDEE -> Goal adjustment -> Calories -> Macros). Сам расчёт
/// целиком на backend — здесь только форма и кнопка "Рассчитать".
class NutritionProfileScreen extends ConsumerStatefulWidget {
  const NutritionProfileScreen({super.key});

  @override
  ConsumerState<NutritionProfileScreen> createState() => _NutritionProfileScreenState();
}

class _NutritionProfileScreenState extends ConsumerState<NutritionProfileScreen> {
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  NutritionSex? _sex;
  ActivityLevel? _activityLevel;
  NutritionGoal? _goal;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await ref.read(nutritionApiServiceProvider).getProfile();
      if (!mounted) return;
      setState(() {
        _sex = profile.sex;
        _age.text = profile.age?.toString() ?? '';
        _height.text = profile.heightCm?.toStringAsFixed(0) ?? '';
        _weight.text = profile.weightKg?.toStringAsFixed(0) ?? '';
        _activityLevel = profile.activityLevel;
        _goal = profile.goal;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _loadError = e.message; _loading = false; });
    }
  }

  bool get _isComplete =>
      _sex != null &&
      int.tryParse(_age.text.trim()) != null &&
      double.tryParse(_height.text.trim()) != null &&
      double.tryParse(_weight.text.trim()) != null &&
      _activityLevel != null &&
      _goal != null;

  Future<void> _saveAndGenerate() async {
    if (!_isComplete || _saving) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(nutritionApiServiceProvider);
      await api.updateProfile(
        sex: _sex,
        age: int.parse(_age.text.trim()),
        heightCm: double.parse(_height.text.trim()),
        weightKg: double.parse(_weight.text.trim()),
        activityLevel: _activityLevel,
        goal: _goal,
      );
      await api.generateTargets();
      await ref.read(nutritionDayProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои данные'), leading: const BackButton()),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(onPressed: _load, child: const Text('Повторить')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
                    children: [
                      Text(
                        'Заполни эти данные, чтобы мы рассчитали персональные цели по калориям, БЖУ и воде',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Пол', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SelectableChip(label: 'Мужской', selected: _sex == NutritionSex.male, onTap: () => setState(() => _sex = NutritionSex.male)),
                          const SizedBox(width: 8),
                          SelectableChip(label: 'Женский', selected: _sex == NutritionSex.female, onTap: () => setState(() => _sex = NutritionSex.female)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _age,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Возраст, лет'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextField(
                              controller: _height,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Рост, см'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextField(
                              controller: _weight,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Вес, кг'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Активность', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      for (final level in ActivityLevel.values)
                        SelectableOptionCard(
                          label: level.label,
                          subtitle: level.description,
                          selected: _activityLevel == level,
                          onTap: () => setState(() => _activityLevel = level),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Цель', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      for (final goal in NutritionGoal.values)
                        SelectableOptionCard(
                          label: goal.label,
                          selected: _goal == goal,
                          onTap: () => setState(() => _goal = goal),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isComplete && !_saving ? _saveAndGenerate : null,
                          child: _saving
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('Рассчитать цели'),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
