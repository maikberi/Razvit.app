enum Gender { male, female }

enum FitnessGoal {
  loseWeight,
  gainMuscle,
  getStronger,
  improveShape,
  endurance,
  maintain,
}

extension FitnessGoalX on FitnessGoal {
  String get label => switch (this) {
        FitnessGoal.loseWeight => 'Похудеть',
        FitnessGoal.gainMuscle => 'Набрать мышечную массу',
        FitnessGoal.getStronger => 'Стать сильнее',
        FitnessGoal.improveShape => 'Улучшить рельеф',
        FitnessGoal.endurance => 'Повысить выносливость',
        FitnessGoal.maintain => 'Поддерживать форму',
      };
}

enum ExperienceLevel { beginner, intermediate, advanced }

extension ExperienceLevelX on ExperienceLevel {
  String get label => switch (this) {
        ExperienceLevel.beginner => 'Новичок',
        ExperienceLevel.intermediate => 'Средний',
        ExperienceLevel.advanced => 'Продвинутый',
      };
}

enum TrainingPlace { gym, home, outdoor, mixed }

extension TrainingPlaceX on TrainingPlace {
  String get label => switch (this) {
        TrainingPlace.gym => 'Тренажёрный зал',
        TrainingPlace.home => 'Дома',
        TrainingPlace.outdoor => 'На улице',
        TrainingPlace.mixed => 'Разное',
      };
}

enum HomeEquipment { dumbbells, pullUpBar, bands, barbell, mat, other, none }

extension HomeEquipmentX on HomeEquipment {
  String get label => switch (this) {
        HomeEquipment.dumbbells => 'Гантели',
        HomeEquipment.pullUpBar => 'Турник',
        HomeEquipment.bands => 'Резинки',
        HomeEquipment.barbell => 'Штанга',
        HomeEquipment.mat => 'Коврик',
        HomeEquipment.other => 'Другое',
        HomeEquipment.none => 'Нет оборудования',
      };
}

enum WorkoutDuration { short, medium, long, extended, veryLong }

extension WorkoutDurationX on WorkoutDuration {
  String get label => switch (this) {
        WorkoutDuration.short => '15–30 минут',
        WorkoutDuration.medium => '30–45 минут',
        WorkoutDuration.long => '45–60 минут',
        WorkoutDuration.extended => '60–90 минут',
        WorkoutDuration.veryLong => 'Более 90 минут',
      };
}

enum Motivation { progress, records, streak, achievements, trainerSupport, stats }

extension MotivationX on Motivation {
  String get label => switch (this) {
        Motivation.progress => 'Видеть прогресс',
        Motivation.records => 'Личные рекорды',
        Motivation.streak => 'Серия тренировок',
        Motivation.achievements => 'Достижения',
        Motivation.trainerSupport => 'Поддержка тренера',
        Motivation.stats => 'Цифры и статистика',
      };
}

enum AiTone { professional, motivating, friendly }

extension AiToneX on AiTone {
  String get label => switch (this) {
        AiTone.professional => 'Профессиональный',
        AiTone.motivating => 'Мотивирующий',
        AiTone.friendly => 'Дружелюбный',
      };
}

/// Анкета онбординга — источник для генерации персонального плана.
class OnboardingProfile {
  const OnboardingProfile({
    this.goal,
    this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.experience,
    this.place,
    this.equipment = const {},
    this.workoutsPerWeek,
    this.duration,
    this.motivation,
    this.aiTone,
  });

  final FitnessGoal? goal;
  final Gender? gender;
  final int? age;
  final int? heightCm;
  final double? weightKg;
  final ExperienceLevel? experience;
  final TrainingPlace? place;
  final Set<HomeEquipment> equipment;
  final int? workoutsPerWeek;
  final WorkoutDuration? duration;
  final Motivation? motivation;
  final AiTone? aiTone;

  bool get isComplete =>
      goal != null &&
      gender != null &&
      age != null &&
      heightCm != null &&
      weightKg != null &&
      experience != null &&
      place != null &&
      workoutsPerWeek != null &&
      duration != null &&
      motivation != null &&
      aiTone != null;

  OnboardingProfile copyWith({
    FitnessGoal? goal,
    Gender? gender,
    int? age,
    int? heightCm,
    double? weightKg,
    ExperienceLevel? experience,
    TrainingPlace? place,
    Set<HomeEquipment>? equipment,
    int? workoutsPerWeek,
    WorkoutDuration? duration,
    Motivation? motivation,
    AiTone? aiTone,
  }) {
    return OnboardingProfile(
      goal: goal ?? this.goal,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      experience: experience ?? this.experience,
      place: place ?? this.place,
      equipment: equipment ?? this.equipment,
      workoutsPerWeek: workoutsPerWeek ?? this.workoutsPerWeek,
      duration: duration ?? this.duration,
      motivation: motivation ?? this.motivation,
      aiTone: aiTone ?? this.aiTone,
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.lastName,
    this.nickname,
    this.avatarUrl,
    this.goal = FitnessGoal.gainMuscle,
    this.heightCm = 177,
    this.weightKg = 89,
    this.startWeightKg = 95,
    this.streakDays = 14,
  });

  final String id;
  final String name;
  final String email;
  final String? lastName;
  final String? nickname;
  final String? avatarUrl;
  final FitnessGoal goal;
  final int heightCm;
  final double weightKg;
  final double startWeightKg;
  final int streakDays;

  AppUser copyWith({
    String? name,
    String? email,
    String? lastName,
    String? nickname,
    double? weightKg,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl,
      goal: goal,
      heightCm: heightCm,
      weightKg: weightKg ?? this.weightKg,
      startWeightKg: startWeightKg,
      streakDays: streakDays,
    );
  }
}
