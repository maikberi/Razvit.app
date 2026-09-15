import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/nutrition.dart';
import '../../../data/models/nutrition_day.dart';
import '../../../data/services/trainer_api_service.dart';

/// Тренер смотрит дневник ОДНОГО клиента и может назначить ему цель/приём
/// пищи/комментарий. Backend сам проверяет approved-связь на каждом
/// запросе (см. TrainerAccessService) — если её нет, любой из вызовов
/// здесь просто вернёт 403, и экран покажет это как обычную ошибку.
class ClientNutritionViewScreen extends ConsumerStatefulWidget {
  const ClientNutritionViewScreen({super.key, required this.clientId, this.clientName});
  final String clientId;
  final String? clientName;

  @override
  ConsumerState<ClientNutritionViewScreen> createState() => _ClientNutritionViewScreenState();
}

class _ClientNutritionViewScreenState extends ConsumerState<ClientNutritionViewScreen> {
  DailyNutritionSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await ref.read(trainerApiServiceProvider).getClientDaily(widget.clientId, DateTime.now());
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openSetPlan() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SetPlanSheet(clientId: widget.clientId),
    );
    if (result == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Цели сохранены')));
  }

  Future<void> _openAssignMeal() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignMealSheet(clientId: widget.clientId),
    );
    if (result == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Приём пищи назначен')));
  }

  Future<void> _openAddComment() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCommentSheet(clientId: widget.clientId),
    );
    if (result == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Комментарий добавлен')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.clientName ?? 'Клиент'), leading: const BackButton()),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(onPressed: _load, child: const Text('Повторить')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Сегодня', style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  _stat(context, 'Калории', '${_summary!.consumedCalories} / ${_summary!.targets.calorieGoal}'),
                                  _stat(context, 'Белки', '${_summary!.consumedProtein.toStringAsFixed(0)} г'),
                                  _stat(context, 'Жиры', '${_summary!.consumedFat.toStringAsFixed(0)} г'),
                                  _stat(context, 'Углеводы', '${_summary!.consumedCarbs.toStringAsFixed(0)} г'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Вода: ${(_summary!.waterConsumedMl / 1000).toStringAsFixed(1)} / ${(_summary!.targets.waterGoalMl / 1000).toStringAsFixed(1)} л', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Приёмы пищи сегодня', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        for (final meal in _summary!.meals)
                          if (meal.items.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(meal.type.label, style: Theme.of(context).textTheme.titleSmall),
                                    const SizedBox(height: 4),
                                    for (final item in meal.items) Text('${item.name} · ${item.grams.round()} г · ${item.calories} ккал', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                            ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: _openSetPlan, child: const Text('Цели'))),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton(onPressed: _openAssignMeal, child: const Text('Назначить приём'))),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton(onPressed: _openAddComment, child: const Text('Комментарий'))),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

class _SetPlanSheet extends ConsumerStatefulWidget {
  const _SetPlanSheet({required this.clientId});
  final String clientId;

  @override
  ConsumerState<_SetPlanSheet> createState() => _SetPlanSheetState();
}

class _SetPlanSheetState extends ConsumerState<_SetPlanSheet> {
  final _title = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(trainerApiServiceProvider).setClientPlan(
            widget.clientId,
            title: _title.text.trim().isEmpty ? null : _title.text.trim(),
            calorieTarget: int.tryParse(_calories.text.trim()),
            proteinTarget: int.tryParse(_protein.text.trim()),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Target', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Название плана (необязательно)')),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: TextField(controller: _calories, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Калории'))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: TextField(controller: _protein, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Белок, г'))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Заметка (необязательно)')),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignMealSheet extends ConsumerStatefulWidget {
  const _AssignMealSheet({required this.clientId});
  final String clientId;

  @override
  ConsumerState<_AssignMealSheet> createState() => _AssignMealSheetState();
}

class _AssignMealSheetState extends ConsumerState<_AssignMealSheet> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(trainerApiServiceProvider).assignMeal(
            widget.clientId,
            title: _title.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Назначить приём пищи', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Что съесть')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Подробности (необязательно)')),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Назначить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCommentSheet extends ConsumerStatefulWidget {
  const _AddCommentSheet({required this.clientId});
  final String clientId;

  @override
  ConsumerState<_AddCommentSheet> createState() => _AddCommentSheetState();
}

class _AddCommentSheetState extends ConsumerState<_AddCommentSheet> {
  final _message = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (_message.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(trainerApiServiceProvider).addComment(widget.clientId, _message.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Комментарий', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          TextField(controller: _message, maxLines: 3, decoration: const InputDecoration(labelText: 'Рекомендация или комментарий')),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Отправить'),
            ),
          ),
        ],
      ),
    );
  }
}
