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

class VolumeEntry {
  const VolumeEntry(this.date, this.volumeKg);
  final DateTime date;
  final double volumeKg;
}

List<VolumeEntry> generateMockMonthlyVolume() {
  final now = DateTime.now();
  final points = <VolumeEntry>[];
  double base = 55000;
  for (var i = 4; i >= 0; i--) {
    final date = now.subtract(Duration(days: i * 7));
    base += 6000 + (i.isEven ? 2000 : -1000);
    points.add(VolumeEntry(date, base));
  }
  return points;
}

final List<VolumeEntry> mockMonthlyVolume = generateMockMonthlyVolume();
