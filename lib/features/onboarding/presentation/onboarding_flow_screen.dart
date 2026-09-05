import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/selectable_option.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/onboarding_repository.dart';
import 'onboarding_widgets.dart';

(IconData, Color, Color) _goalStyle(FitnessGoal g) => switch (g) {
      FitnessGoal.loseWeight => (Icons.local_fire_department_rounded, const Color(0xFFEF4444), const Color(0xFFFEE9E9)),
      FitnessGoal.gainMuscle => (Icons.fitness_center_rounded, AppColors.green600, AppColors.green50),
      FitnessGoal.getStronger => (Icons.bolt_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF4DF)),
      FitnessGoal.improveShape => (Icons.auto_awesome_rounded, const Color(0xFF8B5CF6), const Color(0xFFF2ECFE)),
      FitnessGoal.endurance => (Icons.directions_run_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      FitnessGoal.maintain => (Icons.favorite_rounded, const Color(0xFFEC4899), const Color(0xFFFDE8F3)),
    };

(IconData, Color, Color) _experienceStyle(ExperienceLevel e) => switch (e) {
      ExperienceLevel.beginner => (Icons.eco_rounded, AppColors.green600, AppColors.green50),
      ExperienceLevel.intermediate => (Icons.trending_up_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      ExperienceLevel.advanced => (Icons.emoji_events_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF4DF)),
    };

(IconData, Color, Color) _placeStyle(TrainingPlace p) => switch (p) {
      TrainingPlace.gym => (Icons.fitness_center_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      TrainingPlace.home => (Icons.home_rounded, AppColors.green600, AppColors.green50),
      TrainingPlace.outdoor => (Icons.park_rounded, const Color(0xFF16A34A), AppColors.green50),
      TrainingPlace.mixed => (Icons.public_rounded, const Color(0xFF8B5CF6), const Color(0xFFF2ECFE)),
    };

List<Color> _placeGradient(TrainingPlace p) => switch (p) {
      TrainingPlace.gym => const [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
      TrainingPlace.home => AppColors.greenGradient,
      TrainingPlace.outdoor => const [Color(0xFF34D399), Color(0xFF047857)],
      TrainingPlace.mixed => const [Color(0xFFA78BFA), Color(0xFF6D28D9)],
    };

(IconData, Color, Color) _motivationStyle(Motivation m) => switch (m) {
      Motivation.progress => (Icons.show_chart_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      Motivation.records => (Icons.emoji_events_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF4DF)),
      Motivation.streak => (Icons.local_fire_department_rounded, const Color(0xFFEF4444), const Color(0xFFFEE9E9)),
      Motivation.achievements => (Icons.military_tech_rounded, const Color(0xFF8B5CF6), const Color(0xFFF2ECFE)),
      Motivation.trainerSupport => (Icons.support_agent_rounded, AppColors.green600, AppColors.green50),
      Motivation.stats => (Icons.bar_chart_rounded, const Color(0xFF06B6D4), const Color(0xFFE0FAFE)),
    };

(IconData, Color, Color) _aiToneStyle(AiTone t) => switch (t) {
      AiTone.professional => (Icons.badge_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      AiTone.motivating => (Icons.bolt_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF4DF)),
      AiTone.friendly => (Icons.sentiment_satisfied_alt_rounded, AppColors.green600, AppColors.green50),
    };

(IconData, Color, Color) _durationStyle(WorkoutDuration d) => switch (d) {
      WorkoutDuration.short => (Icons.timer_outlined, const Color(0xFF06B6D4), const Color(0xFFE0FAFE)),
      WorkoutDuration.medium => (Icons.timer_rounded, AppColors.green600, AppColors.green50),
      WorkoutDuration.long => (Icons.hourglass_bottom_rounded, const Color(0xFF3B82F6), const Color(0xFFEAF1FE)),
      WorkoutDuration.extended => (Icons.hourglass_full_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF4DF)),
      WorkoutDuration.veryLong => (Icons.all_inclusive_rounded, const Color(0xFF8B5CF6), const Color(0xFFF2ECFE)),
    };

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _total = 10;

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
      case 3:
        return p.experience != null;
      case 4:
        return p.place != null;
      case 6:
        return p.workoutsPerWeek != null;
      case 7:
        return p.duration != null;
      case 8:
        return p.motivation != null;
      case 9:
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
            Text('ШАГ ${_page + 1} ИЗ $_total', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink500, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _total; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 14,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _page ? AppColors.green500 : AppColors.ink200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: OnboardingWaveBackground()),
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _GoalPage(profile: profile, onSelect: notifier.setGoal),
                      _AboutYouPage(
                        profile: profile,
                        age: _age,
                        onGender: notifier.setGender,
                        onAgeChanged: (v) {
                          setState(() => _age = v);
                          notifier.setAge(v);
                        },
                      ),
                      _HeightWeightPage(
                        height: _height,
                        weight: _weight,
                        onHeightChanged: (v) {
                          setState(() => _height = v);
                          notifier.setHeight(v);
                        },
                        onWeightChanged: (v) {
                          setState(() => _weight = v);
                          notifier.setWeight(v);
                        },
                      ),
                      _ExperiencePage(profile: profile, onSelect: notifier.setExperience),
                      _PlaceEquipmentPage(profile: profile, onPlace: notifier.setPlace, onToggleEquipment: notifier.toggleEquipment),
                      _LimitationsPage(profile: profile, onToggle: notifier.toggleLimitation, onClear: notifier.clearLimitations),
                      _WorkoutsPerWeekPage(profile: profile, onSelect: notifier.setWorkoutsPerWeek),
                      _DurationPage(profile: profile, onSelect: notifier.setDuration),
                      _MotivationPage(profile: profile, onSelect: notifier.setMotivation),
                      _AiTonePage(profile: profile, onSelect: notifier.setAiTone),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CircleNextButton(enabled: _canContinue(profile), onTap: _next, isLast: _page == _total - 1),
                    ],
                  ),
                ),
              ],
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
      title: 'Какая твоя главная цель?',
      subtitle: 'Выбери основную — план построим вокруг неё',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.3,
        children: [
          for (final g in FitnessGoal.values)
            SelectableTileCard(
              label: g.label,
              icon: _goalStyle(g).$1,
              iconColor: _goalStyle(g).$2,
              iconBackground: _goalStyle(g).$3,
              selected: profile.goal == g,
              onTap: () => onSelect(g),
            ),
        ],
      ),
    );
  }
}

class _AboutYouPage extends StatelessWidget {
  const _AboutYouPage({required this.profile, required this.age, required this.onGender, required this.onAgeChanged});
  final OnboardingProfile profile;
  final int age;
  final ValueChanged<Gender> onGender;
  final ValueChanged<int> onAgeChanged;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Расскажи о себе',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Пол', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SelectableTileCard(
                  label: 'Мужчина',
                  icon: Icons.male_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  iconBackground: const Color(0xFFEAF1FE),
                  selected: profile.gender == Gender.male,
                  onTap: () => onGender(Gender.male),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableTileCard(
                  label: 'Женщина',
                  icon: Icons.female_rounded,
                  iconColor: const Color(0xFFEC4899),
                  iconBackground: const Color(0xFFFDE8F3),
                  selected: profile.gender == Gender.female,
                  onTap: () => onGender(Gender.female),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _MetricSlider(
            label: 'Возраст',
            value: '$age лет',
            sliderValue: age.toDouble(),
            min: 12,
            max: 90,
            onChanged: (v) => onAgeChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _HeightWeightPage extends StatelessWidget {
  const _HeightWeightPage({
    required this.height,
    required this.weight,
    required this.onHeightChanged,
    required this.onWeightChanged,
  });

  final int height;
  final double weight;
  final ValueChanged<int> onHeightChanged;
  final ValueChanged<double> onWeightChanged;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Рост и вес',
      subtitle: 'Нужно для расчёта твоего плана и аналитики',
      child: Column(
        children: [
          _MetricSlider(
            label: 'Рост',
            value: '$height см',
            sliderValue: height.toDouble(),
            min: 120,
            max: 220,
            onChanged: (v) => onHeightChanged(v.round()),
          ),
          const SizedBox(height: AppSpacing.xl),
          _MetricSlider(
            label: 'Вес',
            value: '${weight.toStringAsFixed(0)} кг',
            sliderValue: weight.clamp(35, 200),
            min: 35,
            max: 200,
            onChanged: onWeightChanged,
          ),
        ],
      ),
    );
  }
}

class _MetricSlider extends StatelessWidget {
  const _MetricSlider({
    required this.label,
    required this.value,
    required this.sliderValue,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String value;
  final double sliderValue;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppColors.green600, fontSize: 38)),
        Row(
          children: [
            _StepButton(icon: Icons.remove_rounded, onTap: sliderValue > min ? () => onChanged(sliderValue - 1) : null),
            Expanded(
              child: Slider(value: sliderValue, min: min, max: max, onChanged: onChanged),
            ),
            _StepButton(icon: Icons.add_rounded, onTap: sliderValue < max ? () => onChanged(sliderValue + 1) : null),
          ],
        ),
      ],
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
      style: IconButton.styleFrom(backgroundColor: Theme.of(context).cardTheme.color, foregroundColor: Theme.of(context).textTheme.bodyLarge?.color),
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
            SelectableOptionCard(
              label: e.label,
              icon: _experienceStyle(e).$1,
              iconColor: _experienceStyle(e).$2,
              iconBackground: _experienceStyle(e).$3,
              selected: profile.experience == e,
              onTap: () => onSelect(e),
            ),
        ],
      ),
    );
  }
}

class _PlaceEquipmentPage extends StatelessWidget {
  const _PlaceEquipmentPage({required this.profile, required this.onPlace, required this.onToggleEquipment});
  final OnboardingProfile profile;
  final ValueChanged<TrainingPlace> onPlace;
  final ValueChanged<HomeEquipment> onToggleEquipment;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Где и с чем занимаешься?',
      subtitle: 'Выбери место — и что есть под рукой',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [
              for (final p in TrainingPlace.values)
                PlacePhotoTile(
                  label: p.label,
                  icon: _placeStyle(p).$1,
                  gradient: _placeGradient(p),
                  selected: profile.place == p,
                  onTap: () => onPlace(p),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Что у тебя есть?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final eq in HomeEquipment.values)
                SelectableChip(label: eq.label, selected: profile.equipment.contains(eq), onTap: () => onToggleEquipment(eq)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitationsPage extends StatelessWidget {
  const _LimitationsPage({required this.profile, required this.onToggle, required this.onClear});
  final OnboardingProfile profile;
  final ValueChanged<BodyLimitation> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      title: 'Есть ли ограничения или травмы?',
      subtitle: 'Отметь зоны на схеме — учтём при подборе упражнений',
      child: Column(
        children: [
          BodyDiagram(selected: profile.limitations, onToggle: onToggle),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final l in BodyLimitation.values)
                SelectableChip(label: l.label, selected: profile.limitations.contains(l), onTap: () => onToggle(l)),
              SelectableChip(label: 'Нет ограничений', selected: profile.limitations.isEmpty, onTap: onClear),
            ],
          ),
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
            SelectableOptionCard(
              label: d.label,
              icon: _durationStyle(d).$1,
              iconColor: _durationStyle(d).$2,
              iconBackground: _durationStyle(d).$3,
              selected: profile.duration == d,
              onTap: () => onSelect(d),
            ),
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
            SelectableOptionCard(
              label: m.label,
              icon: _motivationStyle(m).$1,
              iconColor: _motivationStyle(m).$2,
              iconBackground: _motivationStyle(m).$3,
              selected: profile.motivation == m,
              onTap: () => onSelect(m),
            ),
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
            SelectableOptionCard(
              label: t.label,
              icon: _aiToneStyle(t).$1,
              iconColor: _aiToneStyle(t).$2,
              iconBackground: _aiToneStyle(t).$3,
              selected: profile.aiTone == t,
              onTap: () => onSelect(t),
            ),
        ],
      ),
    );
  }
}
