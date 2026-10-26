import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/razvit_logo.dart';
import '../../../data/models/nutrition_profile.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/onboarding_repository.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../../data/services/nutrition_api_service.dart';
import '../../../data/services/workout_api_service.dart';
import 'plan_ready_screen.dart';

/// Раньше это была чистая трёхсекундная анимация без единого запроса к
/// backend — ответы на 9 вопросов онбординга никуда не сохранялись, а
/// "план" на следующем экране всегда был одним и тем же статичным моком.
/// Теперь здесь реально: профиль питания -> расчёт целей КБЖУ/воды ->
/// профиль тренировок -> сборка программы из настоящего каталога
/// упражнений — 4 последовательных запроса, каждый со своим шагом в
/// списке (шаг подсвечивается, когда соответствующий запрос уже завершён,
/// а не по таймеру).
class PlanGeneratingScreen extends ConsumerStatefulWidget {
  const PlanGeneratingScreen({super.key});

  @override
  ConsumerState<PlanGeneratingScreen> createState() => _PlanGeneratingScreenState();
}

class _PlanGeneratingScreenState extends ConsumerState<PlanGeneratingScreen> with SingleTickerProviderStateMixin {
  static const _steps = [
    'Сохраняем анкету',
    'Рассчитываем питание',
    'Подбираем упражнения',
    'Собираем программу тренировок',
  ];

  int _visible = 0;
  String? _error;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _run();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _visible = 0;
    });
    final profile = ref.read(onboardingProvider);

    try {
      await ref.read(nutritionApiServiceProvider).updateProfile(
            sex: _sex(profile.gender),
            age: profile.age,
            heightCm: profile.heightCm?.toDouble(),
            weightKg: profile.weightKg,
            activityLevel: _activityLevel(profile.workoutsPerWeek),
            goal: _nutritionGoal(profile.goal),
          );
      if (mounted) setState(() => _visible = 1);

      final nutritionPlan = await ref.read(nutritionApiServiceProvider).generateTargets();
      if (mounted) setState(() => _visible = 2);

      await ref.read(workoutApiServiceProvider).updateProfile(
            experience: profile.experience,
            place: profile.place,
            equipment: profile.equipment,
            workoutsPerWeek: profile.workoutsPerWeek,
            duration: profile.duration,
          );
      if (mounted) setState(() => _visible = 3);

      final program = await ref.read(workoutApiServiceProvider).generateProgram();
      if (mounted) setState(() => _visible = 4);

      // Обновляем список программ пользователя, чтобы свежесгенерированная
      // программа сразу была видна на Главной и во вкладке "Тренировки"
      // без отдельного перезапроса при переходе туда.
      await ref.read(customProgramsProvider.notifier).refresh();

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        context.pushReplacement('/plan-ready', extra: GeneratedPlan(nutrition: nutritionPlan, program: program));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не получилось собрать план. Проверь соединение и попробуй ещё раз.');
    }
  }

  NutritionSex? _sex(Gender? g) => switch (g) {
        Gender.male => NutritionSex.male,
        Gender.female => NutritionSex.female,
        null => null,
      };

  NutritionGoal? _nutritionGoal(FitnessGoal? g) => switch (g) {
        FitnessGoal.loseWeight => NutritionGoal.loseWeight,
        FitnessGoal.gainMuscle => NutritionGoal.gainMuscle,
        FitnessGoal.getStronger => NutritionGoal.getStronger,
        FitnessGoal.improveShape => NutritionGoal.improveShape,
        FitnessGoal.endurance => NutritionGoal.endurance,
        FitnessGoal.maintain => NutritionGoal.maintain,
        null => null,
      };

  /// Онбординг не спрашивает про повседневную активность отдельно (только
  /// про тренировки) — используем число тренировок в неделю как разумную
  /// оценку общего уровня активности для BMR/TDEE (см. ActivityLevel —
  /// это НЕ то же самое, что опыт в тренировках).
  ActivityLevel? _activityLevel(int? workoutsPerWeek) => switch (workoutsPerWeek) {
        null => null,
        <= 2 => ActivityLevel.light,
        3 || 4 => ActivityLevel.moderate,
        5 => ActivityLevel.active,
        _ => ActivityLevel.veryActive,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Transform.scale(scale: 1 + _pulseController.value * 0.08, child: child),
                  child: const RazvitMark(size: 148),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _error == null ? 'Создаём твой\nперсональный план...' : 'Не получилось собрать план',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_error != null) ...[
                  Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink500)),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(onPressed: _run, child: const Text('Попробовать снова')),
                ] else
                  for (var i = 0; i < _steps.length; i++)
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      offset: i <= _visible ? Offset.zero : const Offset(-0.05, 0),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: i < _visible ? 1 : 0.25,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              i < _visible
                                  ? const AnimatedScale(
                                      scale: 1,
                                      duration: Duration(milliseconds: 350),
                                      curve: Curves.elasticOut,
                                      child: Icon(Icons.check_circle_rounded, color: AppColors.green500, size: 20),
                                    )
                                  : const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink300),
                                    ),
                              const SizedBox(width: 12),
                              Text(_steps[i], style: Theme.of(context).textTheme.bodyLarge),
                            ],
                          ),
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
