class WeightEntry {
  const WeightEntry(this.date, this.weightKg);
  final DateTime date;
  final double weightKg;
}

/// Динамика веса за последние ~10 недель: 95 кг → 89 кг.
List<WeightEntry> generateMockWeightHistory() {
  final now = DateTime.now();
  const start = 95.0;
  const end = 89.0;
  final points = <WeightEntry>[];
  for (var i = 10; i >= 0; i--) {
    final date = now.subtract(Duration(days: i * 7));
    final t = (10 - i) / 10;
    final wobble = (i % 3 == 0) ? 0.3 : -0.2;
    final weight = start + (end - start) * t + wobble;
    points.add(WeightEntry(date, double.parse(weight.toStringAsFixed(1))));
  }
  points[points.length - 1] = WeightEntry(now, end);
  return points;
}

final List<WeightEntry> mockWeightHistory = generateMockWeightHistory();
