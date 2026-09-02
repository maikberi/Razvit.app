import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/onboarding_repository.dart';

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _total = 12;

  int _age = 25;
  int _height = 177;
  double _weight = 87;

  void _next() {
    if (_page == _total - 1) {
      context.push('/plan-generating');
      return;
    }
    setState(() => _page++);
    _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_page == 0) {
      context.pop();
      return;
    }
    setState(() => _page--);
    _controller.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  bool _canContinue(OnboardingProfile p) {
    switch (_page) {
      case 0:
        return p.goal != null;
      case 1:
        return p.gender != null;
      case 5:
        return p.experience != null;
      case 6:
        return p.place != null;
      case 8:
        return p.workoutsPerWeek != null;
      case 9:
        return p.duration != null;
      case 10:
        return p.motivation != null;
      case 11:
        return p.aiTone != null;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
        title: Column(
          children: [
            Text('${_page + 1} из $_total', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.ink500)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                width: 140,
                height: 5,
                child: LinearProgressIndicator(value: (_page + 1) / _total, backgroundColor: AppColors.ink200),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _GoalPage(profile: profile, onSelect: notifier.setGoal),
                  _GenderPage(profile: profile, onSelect: notifier.setGender),
                  _NumberPage(
                    title: 'Сколько тебе лет?',
                    value: _age,
                    unit: 'лет',
                    min: 12,
                    max: 90,
                    onChanged: (v) {
                      setState(() => _age = v);
                      notifier.setAge(v);
                    },
                  ),
                  _NumberPage(
                    title: 'Какой у тебя рост?',
                    value: _height,
                    unit: 'см',
                    min: 120,
                    max: 220,
                    onChanged: (v) {
                      setState(() => _height = v);
                      notifier.setHeight(v);
                    },
                  ),
                  _WeightPage(
                    value: _weight,
                    onChanged: (v) {
                      setState(() => _weight = v);
                      notifier.setWeight(v);
                    },
                  ),
                  _ExperiencePage(profile: profile, onSelect: notifier.setExperience),
                  _PlacePage(profile: profile, onSelect: notifier.setPlace),
                  _EquipmentPage(profile: profile, onToggle: notifier.toggleEquipment),
                  _WorkoutsPerWeekPage(profile: profile, onSelect: notifier.setWorkoutsPerWeek),
                  _DurationPage(profile: profile, onSelect: notifier.setDuration),
                  _MotivationPage(profile: profile, onSelect: notifier.setMotivation),
                  _AiTonePage(profile: profile, onSelect: notifier.setAiTone),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
              child: ElevatedButton(
                onPressed: _canContinue(profile) ? _next : null,
                child: Text(_page == _total - 1 ? 'Готово' : 'Далее'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionScaffold extends StatelessWidget {
  const _QuestionScaffold({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
          ],
          const SizedBox(height: AppSpacing.xl),
          child,
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  const _GoalPage({required this.profile, required this.onSelect});
  final OnboardingProfile profile;
  final ValueChanged<FitnessGoal> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Какая у тебя главная цель?',
      subtitle: 'Выбери основную — план построим вокруг неё',
      child: Column(
        children: [
          for (final g in FitnessGoal.values)
            SelectableOptionCard(label: g.label, selected: profile.goal == g, onTap: () => onSelect(g)),
        ],
      ),
    );
  }
}

class _GenderPage extends StatelessWidget {
  const _GenderPage({required this.profile, required this.onSelect});
  final OnboardingProfile profile;
  final ValueChanged<Gender> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Укажи свой пол',
      child: Column(
        children: [
          SelectableOptionCard(
            label: 'Мужчина',
            icon: Icons.male_rounded,
            selected: profile.gender == Gender.male,
            onTap: () => onSelect(Gender.male),
          ),
          SelectableOptionCard(
            label: 'Женщина',
            icon: Icons.female_rounded,
            selected: profile.gender == Gender.female,
            onTap: () => onSelect(Gender.female),
          ),
        ],
      ),
    );
  }
}

class _NumberPage extends StatelessWidget {
  const _NumberPage({
    required this.title,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final int value;
  final String unit;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: title,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text('$value $unit', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppColors.green600, fontSize: 44)),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(icon: Icons.remove_rounded, onTap: value > min ? () => onChanged(value - 1) : null),
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
              _StepButton(icon: Icons.add_rounded, onTap: value < max ? () => onChanged(value + 1) : null),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightPage extends StatelessWidget {
  const _WeightPage({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Какой у тебя вес?',
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text('${value.toStringAsFixed(0)} кг', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppColors.green600, fontSize: 44)),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(icon: Icons.remove_rounded, onTap: () => onChanged(value - 1)),
              Expanded(
                child: Slider(value: value.clamp(35, 200), min: 35, max: 200, onChanged: onChanged),
              ),
              _StepButton(icon: Icons.add_rounded, onTap: () => onChanged(value + 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon),
      style: IconButton.styleFrom(backgroundColor: AppColors.ink100, foregroundColor: AppColors.ink900),
    );
  }
}

class _ExperiencePage extends StatelessWidget {
  const _ExperiencePage({required this.profile, required this.onSelect});
  final OnboardingProfile profile;
  final ValueChanged<ExperienceLevel> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Какой у тебя уровень подготовки?',
      child: Column(
        children: [
          for (final e in ExperienceLevel.values)
            SelectableOptionCard(label: e.label, selected: profile.experience == e, onTap: () => onSelect(e)),
        ],
      ),
    );
  }
}

class _PlacePage extends StatelessWidget {
  const _PlacePage({required this.profile, required this.onSelect});
  final OnboardingProfile profile;
  final ValueChanged<TrainingPlace> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Где тренируешься?',
      child: Column(
        children: [
          for (final p in TrainingPlace.values)
            SelectableOptionCard(label: p.label, selected: profile.place == p, onTap: () => onSelect(p)),
        ],
      ),
    );
  }
}

class _EquipmentPage extends StatelessWidget {
  const _EquipmentPage({required this.profile, required this.onToggle});
  final OnboardingProfile profile;
  final ValueChanged<HomeEquipment> onToggle;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Какое оборудование доступно?',
      subtitle: 'Можно выбрать несколько вариантов',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final eq in HomeEquipment.values)
            SelectableChip(label: eq.label, selected: profile.equipment.contains(eq), onTap: () => onToggle(eq)),
        ],
      ),
    );
  }
}

class _WorkoutsPerWeekPage extends StatelessWidget {
  const _WorkoutsPerWeekPage({required this.profile, required this.onSelect});
  final OnboardingProfile profile;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Сколько тренировок в неделю?',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final n in [2, 3, 4, 5, 6])
            SelectableChip(label: '$n', selected: profile.workoutsPerWeek == n, onTap: () => onSelect(n)),
        ],
      ),
    );
  }
}

class _DurationPage extends StatelessWidget {
  const _DurationPage({required this.profile, required this.onSelect});
  final OnboardingProfile profile;
  final ValueChanged<WorkoutDuration> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Сколько времени готов уделять тренировке?',
      child: Column(
        children: [
          for (final d in WorkoutDuration.values)
            SelectableOptionCard(label: d.label, selected: profile.duration == d, onTap: () => onSelect(d)),
        ],
      ),
    );
  }
}

class _MotivationPage extends StatelessWidget {
  const _MotivationPage({required this.profile, required this.onSelect});
  final OnboardingProfile profile;
  final ValueChanged<Motivation> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Что тебя мотивирует?',
      subtitle: 'Настроим акценты интерфейса под тебя',
      child: Column(
        children: [
          for (final m in Motivation.values)
            SelectableOptionCard(label: m.label, selected: profile.motivation == m, onTap: () => onSelect(m)),
        ],
      ),
    );
  }
}

class _AiTonePage extends StatelessWidget {
  const _AiTonePage({required this.profile, required this.onSelect});
  final OnboardingProfile profile;
  final ValueChanged<AiTone> onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Каким должен быть AI-помощник?',
      subtitle: 'Это повлияет на стиль сообщений AI-наставника',
      child: Column(
        children: [
          for (final t in AiTone.values)
            SelectableOptionCard(label: t.label, selected: profile.aiTone == t, onTap: () => onSelect(t)),
        ],
      ),
    );
  }
}
