/// Данные, которые Nutrition Target Service на backend использует для
/// расчёта персональных целей (BMR/TDEE -> Goal adjustment -> Calories ->
/// Macros, см. backend nutritionTarget.service.ts). Отдельная небольшая
/// модель, а не переиспользование Gender/FitnessGoal из онбординга —
/// сейчас онбординг ничего не сохраняет на backend (только локальная
/// демонстрация), а этот профиль — реальный, персистентный источник
/// данных для расчёта целей.
enum NutritionSex { male, female }

extension NutritionSexX on NutritionSex {
  String get apiValue => name;
  String get label => this == NutritionSex.male ? 'Мужской' : 'Женский';

  static NutritionSex? fromApi(String? raw) => switch (raw) {
        'male' => NutritionSex.male,
        'female' => NutritionSex.female,
        _ => null,
      };
}

/// Стандартная 5-ступенчатая шкала активности для TDEE — НЕ то же самое,
/// что уровень опыта в тренировках (см. ExperienceLevel в онбординге):
/// здесь про то, сколько человек двигается в течение обычного дня.
enum ActivityLevel { sedentary, light, moderate, active, veryActive }

extension ActivityLevelX on ActivityLevel {
  String get apiValue => switch (this) {
        ActivityLevel.sedentary => 'sedentary',
        ActivityLevel.light => 'light',
        ActivityLevel.moderate => 'moderate',
        ActivityLevel.active => 'active',
        ActivityLevel.veryActive => 'very_active',
      };

  String get label => switch (this) {
        ActivityLevel.sedentary => 'Малоподвижный',
        ActivityLevel.light => 'Лёгкая активность',
        ActivityLevel.moderate => 'Средняя активность',
        ActivityLevel.active => 'Высокая активность',
        ActivityLevel.veryActive => 'Очень высокая активность',
      };

  String get description => switch (this) {
        ActivityLevel.sedentary => 'Сидячая работа, почти нет тренировок',
        ActivityLevel.light => 'Лёгкие тренировки 1-3 раза в неделю',
        ActivityLevel.moderate => 'Тренировки 3-5 раз в неделю',
        ActivityLevel.active => 'Интенсивные тренировки 6-7 раз в неделю',
        ActivityLevel.veryActive => 'Физическая работа + тренировки каждый день',
      };

  static ActivityLevel? fromApi(String? raw) => switch (raw) {
        'sedentary' => ActivityLevel.sedentary,
        'light' => ActivityLevel.light,
        'moderate' => ActivityLevel.moderate,
        'active' => ActivityLevel.active,
        'very_active' => ActivityLevel.veryActive,
        _ => null,
      };
}

/// Те же 6 значений, что и FitnessGoal в онбординге — сознательно
/// отдельный enum (модуль питания не должен зависеть от модуля
/// онбординга), но с тем же смыслом и подписями, чтобы выбор "Цель" не
/// путал пользователя разными формулировками в разных местах приложения.
enum NutritionGoal { loseWeight, gainMuscle, getStronger, improveShape, endurance, maintain }

extension NutritionGoalX on NutritionGoal {
  String get apiValue => switch (this) {
        NutritionGoal.loseWeight => 'lose_weight',
        NutritionGoal.gainMuscle => 'gain_muscle',
        NutritionGoal.getStronger => 'get_stronger',
        NutritionGoal.improveShape => 'improve_shape',
        NutritionGoal.endurance => 'endurance',
        NutritionGoal.maintain => 'maintain',
      };

  String get label => switch (this) {
        NutritionGoal.loseWeight => 'Похудение',
        NutritionGoal.gainMuscle => 'Набор мышечной массы',
        NutritionGoal.getStronger => 'Стать сильнее',
        NutritionGoal.improveShape => 'Улучшить форму',
        NutritionGoal.endurance => 'Выносливость',
        NutritionGoal.maintain => 'Поддержание веса',
      };

  static NutritionGoal? fromApi(String? raw) => switch (raw) {
        'lose_weight' => NutritionGoal.loseWeight,
        'gain_muscle' => NutritionGoal.gainMuscle,
        'get_stronger' => NutritionGoal.getStronger,
        'improve_shape' => NutritionGoal.improveShape,
        'endurance' => NutritionGoal.endurance,
        'maintain' => NutritionGoal.maintain,
        _ => null,
      };
}

class NutritionProfile {
  const NutritionProfile({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
  });

  final NutritionSex? sex;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel? activityLevel;
  final NutritionGoal? goal;

  /// Все шесть полей заданы — только тогда backend может посчитать цели
  /// (POST /nutrition/targets/generate), см. NutritionTargetService на backend.
  bool get isComplete => sex != null && age != null && heightCm != null && weightKg != null && activityLevel != null && goal != null;

  factory NutritionProfile.fromJson(Map<String, dynamic> json) => NutritionProfile(
        sex: NutritionSexX.fromApi(json['sex'] as String?),
        age: (json['age'] as num?)?.round(),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        activityLevel: ActivityLevelX.fromApi(json['activityLevel'] as String?),
        goal: NutritionGoalX.fromApi(json['goal'] as String?),
      );
}
