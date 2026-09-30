import 'dart:math';

/// Дневная запись питания — используется графиками статистики.
class NutritionDayLog {
  const NutritionDayLog({
    required this.date,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.waterMl,
  });

  final DateTime date;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final int waterMl;
}

/// Генерирует правдоподобную историю питания за [days] дней вокруг целей
/// текущего плана — используется статистикой, пока в приложении нет
/// сохранения дневных логов на бэкенде. Сегодняшний день сюда не входит:
/// его подставляют из реального состояния (mealsProvider/waterIntakeProvider).
List<NutritionDayLog> generateMockNutritionHistory({
  int days = 90,
  required int calorieGoal,
  required int proteinGoal,
  required int fatGoal,
  required int carbsGoal,
  required int waterGoalMl,
}) {
  final rnd = Random(7);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final list = <NutritionDayLog>[];

  for (var offset = days; offset >= 1; offset--) {
    final date = today.subtract(Duration(days: offset));
    final calorieVariance = 0.85 + rnd.nextDouble() * 0.3;
    final macroVariance = 0.8 + rnd.nextDouble() * 0.4;
    final waterVariance = 0.6 + rnd.nextDouble() * 0.55;
    list.add(NutritionDayLog(
      date: date,
      calories: (calorieGoal * calorieVariance).round(),
      protein: proteinGoal * macroVariance,
      fat: fatGoal * macroVariance,
      carbs: carbsGoal * macroVariance,
      waterMl: (waterGoalMl * waterVariance).round().clamp(0, waterGoalMl + 500),
    ));
  }
  return list;
}
