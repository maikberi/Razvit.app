import '../models/achievement.dart';

final List<Achievement> mockAchievements = [
  const Achievement(id: 'first_workout', emoji: '🏆', title: 'Первая тренировка', description: 'Ты начал свой путь в RAZVIT', isUnlocked: true),
  const Achievement(id: 'streak_7', emoji: '🔥', title: '7 дней подряд', description: 'Неделя без пропусков', isUnlocked: true),
  const Achievement(id: 'streak_30', emoji: '🔥', title: '30 дней подряд', description: 'Месяц стабильности', isUnlocked: false, progress: 14, target: 30),
  const Achievement(id: 'new_pr', emoji: '💪', title: 'Новый личный рекорд', description: 'Превзошёл свой прошлый максимум', isUnlocked: true),
  const Achievement(id: 'workouts_100', emoji: '🏋️', title: '100 тренировок', description: 'Сотня тренировок позади', isUnlocked: false, progress: 47, target: 100),
  const Achievement(id: 'volume_10000', emoji: '⚡', title: '10 000 кг объёма', description: 'За одну тренировку', isUnlocked: true),
];
