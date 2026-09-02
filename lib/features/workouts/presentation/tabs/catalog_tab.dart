import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/selectable_option.dart';
import '../../../../data/models/exercise.dart';
import '../../../../data/repositories/workout_repository.dart';

class CatalogTab extends ConsumerStatefulWidget {
  const CatalogTab({super.key, this.initialFilter});

  final MuscleGroup? initialFilter;

  @override
  ConsumerState<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<CatalogTab> {
  MuscleGroup? _filter;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(covariant CatalogTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != null && widget.initialFilter != oldWidget.initialFilter) {
      _filter = widget.initialFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(exerciseCatalogProvider);
    final query = _search.text.trim().toLowerCase();
    final filtered = all.where((e) {
      final matchesGroup = _filter == null || e.primaryMuscle == _filter;
      final matchesQuery = query.isEmpty || e.name.toLowerCase().contains(query);
      return matchesGroup && matchesQuery;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Поиск упражнений',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.ink400),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SelectableChip(label: 'Все', selected: _filter == null, onTap: () => setState(() => _filter = null)),
              ),
              for (final g in MuscleGroup.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SelectableChip(label: g.label, selected: _filter == g, onTap: () => setState(() => _filter = g)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(emoji: '🔍', title: 'Ничего не найдено', subtitle: 'Попробуй изменить запрос или фильтр')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _ExerciseRow(exercise: filtered[i]),
                ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/exercise/${exercise.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.ink800, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.fitness_center_rounded, color: Colors.white70, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(exercise.primaryMuscle.label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            exercise.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: exercise.isFavorite ? AppColors.warning : AppColors.ink300,
          ),
        ],
      ),
    );
  }
}
