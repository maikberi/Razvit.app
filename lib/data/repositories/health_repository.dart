import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Подключение к системному трекеру здоровья (Apple Health / Google Fit).
/// В веб-версии реального доступа к сенсорам нет, поэтому после
/// "подключения" шаги считаются по правдоподобной мок-модели дня.
class HealthConnectionNotifier extends StateNotifier<bool> {
  HealthConnectionNotifier() : super(false);

  void setConnected(bool value) => state = value;
}

final healthConnectedProvider = StateNotifierProvider<HealthConnectionNotifier, bool>((ref) => HealthConnectionNotifier());

const int dailyStepsGoal = 10000;

/// Правдоподобное количество шагов на текущий момент дня — растёт в течение
/// дня и не появляется, пока пользователь не подключил "Здоровье".
final dailyStepsProvider = Provider<int>((ref) {
  final connected = ref.watch(healthConnectedProvider);
  if (!connected) return 0;

  final now = DateTime.now();
  final dayFraction = (now.hour * 60 + now.minute) / (24 * 60);
  final base = (dailyStepsGoal * 0.9 * dayFraction).round();
  final noise = Random(now.day).nextInt(800);
  return base + noise;
});
