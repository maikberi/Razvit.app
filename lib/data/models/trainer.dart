enum TrainerSpecialization { mass, loss, strength, definition, functional }

extension TrainerSpecializationX on TrainerSpecialization {
  String get label => switch (this) {
        TrainerSpecialization.mass => 'Набор массы',
        TrainerSpecialization.loss => 'Похудение',
        TrainerSpecialization.strength => 'Сила',
        TrainerSpecialization.definition => 'Рельеф',
        TrainerSpecialization.functional => 'Функциональный тренинг',
      };
}

class Trainer {
  const Trainer({
    required this.id,
    required this.name,
    required this.isVerified,
    required this.rating,
    required this.reviewsCount,
    required this.clientsCount,
    required this.experienceYears,
    required this.specializations,
    required this.pricePerMonth,
    required this.responseTime,
    this.isOnline = false,
    this.avatarSeed = 0,
    this.bio = '',
  });

  final String id;
  final String name;
  final bool isVerified;
  final double rating;
  final int reviewsCount;
  final int clientsCount;
  final int experienceYears;
  final List<TrainerSpecialization> specializations;
  final int pricePerMonth;
  final String responseTime;
  final bool isOnline;
  final int avatarSeed;
  final String bio;
}

enum MessageSender { user, trainer, ai }

class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    required this.time,
  });

  final MessageSender sender;
  final String text;
  final String time;
}
