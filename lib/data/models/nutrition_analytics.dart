enum AnalyticsPeriod { d7, d30, d90 }

extension AnalyticsPeriodX on AnalyticsPeriod {
  String get apiValue => switch (this) {
        AnalyticsPeriod.d7 => '7d',
        AnalyticsPeriod.d30 => '30d',
        AnalyticsPeriod.d90 => '90d',
      };

  String get label => switch (this) {
        AnalyticsPeriod.d7 => '7 дней',
        AnalyticsPeriod.d30 => '30 дней',
        AnalyticsPeriod.d90 => '90 дней',
      };
}

/// Один день из ответа backend — уже готовые суммы (Nutrition Engine),
/// Flutter здесь ничего не считает, только рисует.
class NutritionAnalyticsDay {
  const NutritionAnalyticsDay({
    required this.date,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.waterMl,
    required this.hasEntries,
    required this.onTarget,
  });

  final DateTime date;
  final int calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final int waterMl;
  final bool hasEntries;
  final bool onTarget;

  factory NutritionAnalyticsDay.fromJson(Map<String, dynamic> json) => NutritionAnalyticsDay(
        date: DateTime.parse(json['date'] as String),
        calories: (json['calories'] as num).round(),
        protein: (json['protein'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        carbohydrates: (json['carbohydrates'] as num).toDouble(),
        waterMl: (json['waterMl'] as num).round(),
        hasEntries: json['hasEntries'] as bool,
        onTarget: json['onTarget'] as bool,
      );
}

class NutritionAnalyticsAverages {
  const NutritionAnalyticsAverages({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.waterMl,
  });

  final int calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final int waterMl;

  factory NutritionAnalyticsAverages.fromJson(Map<String, dynamic> json) => NutritionAnalyticsAverages(
        calories: (json['calories'] as num).round(),
        protein: (json['protein'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        carbohydrates: (json['carbohydrates'] as num).toDouble(),
        waterMl: (json['waterMl'] as num).round(),
      );
}

/// Ответ GET /nutrition/analytics?period= — вся статистика уже посчитана
/// backend'ом (агрегация по дням, максимум 90 точек), Flutter не грузит
/// сырые записи за месяцы и ничего сам не усредняет.
class NutritionAnalyticsResult {
  const NutritionAnalyticsResult({
    required this.period,
    required this.days,
    required this.averages,
    required this.goalAdherencePercent,
    required this.daysOnTarget,
    required this.loggedDays,
    required this.totalDays,
    required this.calorieGoal,
    required this.waterGoalMl,
  });

  final AnalyticsPeriod period;
  final List<NutritionAnalyticsDay> days;
  final NutritionAnalyticsAverages averages;
  final int goalAdherencePercent;
  final int daysOnTarget;
  final int loggedDays;
  final int totalDays;
  final int calorieGoal;
  final int waterGoalMl;

  factory NutritionAnalyticsResult.fromJson(Map<String, dynamic> json) => NutritionAnalyticsResult(
        period: AnalyticsPeriod.values.firstWhere((p) => p.apiValue == json['period']),
        days: (json['days'] as List<dynamic>).map((e) => NutritionAnalyticsDay.fromJson(e as Map<String, dynamic>)).toList(),
        averages: NutritionAnalyticsAverages.fromJson(json['averages'] as Map<String, dynamic>),
        goalAdherencePercent: (json['goalAdherencePercent'] as num).round(),
        daysOnTarget: (json['daysOnTarget'] as num).round(),
        loggedDays: (json['loggedDays'] as num).round(),
        totalDays: (json['totalDays'] as num).round(),
        calorieGoal: ((json['targets'] as Map<String, dynamic>)['calorieGoal'] as num).round(),
        waterGoalMl: ((json['targets'] as Map<String, dynamic>)['waterGoalMl'] as num).round(),
      );
}
