import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/selectable_option.dart';
import '../../../../data/models/exercise.dart';
import '../../../../data/services/exercise_api_service.dart';
import '../widgets/exercise_media.dart';

/// Каталог упражнений из настоящей библиотеки backend (GET /exercises,
/// см. exercise_api_service.dart) — с анимациями техники выполнения,
/// вместо прежнего захардкоженного mockExercises (25 шт., почти без медиа).
class CatalogTab extends ConsumerStatefulWidget {
  const CatalogTab({super.key, this.initialFilter});

  final MuscleGroup? initialFilter;

  @override
  ConsumerState<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<CatalogTab> {
  MuscleGroup? _filter;
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<Exercise> _results = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _scrollController.addListener(_onScroll);
    _runSearch(reset: true);
  }

  @override
  void didUpdateWidget(covariant CatalogTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != null && widget.initialFilter != oldWidget.initialFilter) {
      setState(() => _filter = widget.initialFilter);
      _runSearch(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || _error != null || _page >= _totalPages) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _runSearch(reset: false);
    }
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(reset: true));
  }

  void _onFilterChanged(MuscleGroup? group) {
    setState(() => _filter = group);
    _runSearch(reset: true);
  }

  Future<void> _runSearch({required bool reset}) async {
    setState(() {
      if (reset) {
        _loading = true;
        _page = 1;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });

    try {
      final page = reset ? 1 : _page + 1;
      final result = await ref.read(exerciseApiServiceProvider).search(
            query: _search.text,
            muscleGroup: _filter,
            page: page,
          );
      if (!mounted) return;
      setState(() {
        _results = reset ? result.items : [..._results, ...result.items];
        _page = result.page;
        _totalPages = result.totalPages;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TextField(
            controller: _search,
            onChanged: _onQueryChanged,
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
                child: SelectableChip(label: 'Все', selected: _filter == null, onTap: () => _onFilterChanged(null)),
              ),
              for (final g in MuscleGroup.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SelectableChip(label: g.label, selected: _filter == g, onTap: () => _onFilterChanged(g)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _results.isEmpty) {
      return EmptyState(
        emoji: '⚠️',
        title: 'Не удалось загрузить упражнения',
        subtitle: _error,
        actionLabel: 'Повторить',
        onAction: () => _runSearch(reset: true),
      );
    }
    if (_results.isEmpty) {
      return const EmptyState(emoji: '🔍', title: 'Ничего не найдено', subtitle: 'Попробуй изменить запрос или фильтр');
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      itemCount: _results.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        if (i == _results.length) {
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error))),
                  TextButton(onPressed: () => _runSearch(reset: false), child: const Text('Повторить')),
                ],
              ),
            );
          }
          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          return const SizedBox.shrink();
        }
        return _ExerciseRow(exercise: _results[i]);
      },
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/exercise/${exercise.id}', extra: exercise),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          ExerciseThumb(exercise: exercise, size: 52),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text('${exercise.primaryMuscle.label} · ${exercise.equipment}', style: Theme.of(context).textTheme.bodySmall),
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
