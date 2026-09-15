/// Склонение числительных в русском языке по стандартным правилам:
/// 1, 21, 31... → [one]; 2-4, 22-24... → [few]; 5-20, 11-14, 0... → [many].
String ruPlural(int n, {required String one, required String few, required String many}) {
  final mod100 = n.abs() % 100;
  final mod10 = n.abs() % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

String yearsLabel(int n) => ruPlural(n, one: 'год', few: 'года', many: 'лет');

String weeksLabel(int n) => ruPlural(n, one: 'неделю', few: 'недели', many: 'недель');
