import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/workout_repository.dart';
import '../workouts/presentation/widgets/exercise_media.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (icon: Icons.home_rounded, outlineIcon: Icons.home_outlined, label: 'Главная'),
    (icon: Icons.fitness_center_rounded, outlineIcon: Icons.fitness_center_outlined, label: 'Тренировки'),
    (icon: Icons.eco_rounded, outlineIcon: Icons.eco_outlined, label: 'Питание'),
    (icon: Icons.support_agent_rounded, outlineIcon: Icons.support_agent_outlined, label: 'Тренер'),
    (icon: Icons.person_rounded, outlineIcon: Icons.person_outline_rounded, label: 'Профиль'),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Раньше GIF-анимации упражнений прогревались в кэш (см. exercise_media.dart)
/// только в момент старта конкретной тренировки — пока пользователь листал
/// программу/каталог до этого, каждая GIF качалась с нуля при первом
/// открытии карточки упражнения, что на медленной сети (GitHub Pages из
/// России) ощущалось как "висит по несколько минут". Теперь прогрев всего
/// каталога и текущей активной программы запускается один раз сразу при
/// входе в приложение (здесь, в корневой навигации) — к моменту, когда
/// пользователь долистает до упражнений, большая часть уже в кэше.
class _AppShellState extends ConsumerState<AppShell> {
  bool _prefetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefetched) return;
    _prefetched = true;
    final catalog = ref.read(exerciseCatalogProvider);
    prefetchExerciseMedia(catalog);
    final program = ref.read(activeProgramProvider);
    for (final day in program.days) {
      prefetchExerciseMedia(day.exercises.map((e) => e.exercise));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < AppShell._items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: AppShell._items[i].icon,
                      outlineIcon: AppShell._items[i].outlineIcon,
                      label: AppShell._items[i].label,
                      selected: widget.navigationShell.currentIndex == i,
                      onTap: () => widget.navigationShell.goBranch(
                        i,
                        initialLocation: i == widget.navigationShell.currentIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.outlineIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData outlineIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green600 : AppColors.ink400;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? (context.isDarkMode ? AppColors.green500.withValues(alpha: 0.18) : AppColors.green50) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? icon : outlineIcon, color: color, size: 22),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
