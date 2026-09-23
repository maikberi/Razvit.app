import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/exercise.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/my_program_tab.dart';

enum _WorkoutsSegment { myProgram, catalog }

/// Раздел "Тренировки" — раньше было 3 вкладки (Моя программа / Каталог /
/// Создать), причём "Создать" почти дублировала блок "Мои программы" из
/// первой вкладки (тот же список + та же кнопка "Создать программу").
/// Убрали лишнюю вкладку — два чётких раздела вместо трёх похожих.
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  _WorkoutsSegment _segment = _WorkoutsSegment.myProgram;
  MuscleGroup? _catalogFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировки'),
        actions: [
          IconButton(
            onPressed: () => context.push('/workout-stats'),
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Статистика',
          ),
          IconButton(
            onPressed: () => context.push('/workout-calendar'),
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Календарь',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: SelectableChip(
                    label: 'Моя программа',
                    selected: _segment == _WorkoutsSegment.myProgram,
                    onTap: () => setState(() => _segment = _WorkoutsSegment.myProgram),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableChip(
                    label: 'Каталог',
                    selected: _segment == _WorkoutsSegment.catalog,
                    onTap: () => setState(() => _segment = _WorkoutsSegment.catalog),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_segment) {
              _WorkoutsSegment.myProgram => MyProgramTab(
                  onCategoryTap: (g) => setState(() {
                    _catalogFilter = g;
                    _segment = _WorkoutsSegment.catalog;
                  }),
                ),
              _WorkoutsSegment.catalog => CatalogTab(initialFilter: _catalogFilter),
            },
          ),
        ],
      ),
    );
  }
}
