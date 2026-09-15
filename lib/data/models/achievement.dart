class Achievement {
  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.isUnlocked,
    this.progress,
    this.target,
  });

  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool isUnlocked;
  final int? progress;
  final int? target;
}
