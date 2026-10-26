/// Одна запись веса пользователя (см. ProgressApiService — GET/POST /weight-entries).
class WeightEntry {
  const WeightEntry(this.date, this.weightKg);
  final DateTime date;
  final double weightKg;
}
