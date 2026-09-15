import '../../data/models/user.dart';

class GeneratedPlanSummary {
  const GeneratedPlanSummary({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.waterMl,
    required this.workoutsPerWeek,
    required this.durationLabel,
  });

  final int calories;
  final int protein;
  final int fat;
  final int carbs;
  final int waterMl;
  final int workoutsPerWeek;
  final String durationLabel;
}

/// Простой расчёт персонального плана по формуле Миффлина-Сан Жеора —
/// достаточно для MVP-демонстрации онбординга.
GeneratedPlanSummary calculatePlan(OnboardingProfile profile) {
  final weight = profile.weightKg ?? 80;
  final height = profile.heightCm ?? 175;
  final age = profile.age ?? 28;
  final isMale = (profile.gender ?? Gender.male) == Gender.male;

  final bmr = isMale
      ? 10 * weight + 6.25 * height - 5 * age + 5
      : 10 * weight + 6.25 * height - 5 * age - 161;

  final sessions = profile.workoutsPerWeek ?? 4;
  final activityFactor = 1.2 + (sessions * 0.075);
  var calories = bmr * activityFactor;

  switch (profile.goal) {
    case FitnessGoal.loseWeight:
      calories -= 400;
    case FitnessGoal.gainMuscle:
      calories += 300;
    case FitnessGoal.getStronger:
      calories += 150;
    case FitnessGoal.endurance:
    case FitnessGoal.improveShape:
    case FitnessGoal.maintain:
    case null:
      break;
  }

  final proteinPerKg = profile.goal == FitnessGoal.gainMuscle || profile.goal == FitnessGoal.getStronger ? 2.0 : 1.7;
  final protein = weight * proteinPerKg;
  final fat = weight * 0.9;
  final proteinCal = protein * 4;
  final fatCal = fat * 9;
  final carbsCal = (calories - proteinCal - fatCal).clamp(0, double.infinity);
  final carbs = carbsCal / 4;

  final waterMl = (weight * 33).round();

  return GeneratedPlanSummary(
    calories: calories.round(),
    protein: protein.round(),
    fat: fat.round(),
    carbs: carbs.round(),
    waterMl: waterMl,
    workoutsPerWeek: sessions,
    durationLabel: profile.duration?.label ?? '45–60 минут',
  );
}
