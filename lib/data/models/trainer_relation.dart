enum TrainerRelationStatus { pending, approved, declined, revoked }

extension TrainerRelationStatusX on TrainerRelationStatus {
  static TrainerRelationStatus fromApi(String raw) => switch (raw) {
        'approved' => TrainerRelationStatus.approved,
        'declined' => TrainerRelationStatus.declined,
        'revoked' => TrainerRelationStatus.revoked,
        _ => TrainerRelationStatus.pending,
      };
}

/// Кто по другую сторону связи — backend отдаёт это вместе со списком
/// связей одним батч-запросом, чтобы Flutter не видел голые UUID.
class TrainerCounterpart {
  const TrainerCounterpart({required this.id, required this.email, required this.name});
  final String id;
  final String email;
  final String name;

  factory TrainerCounterpart.fromJson(Map<String, dynamic> json) =>
      TrainerCounterpart(id: json['id'] as String, email: json['email'] as String, name: json['name'] as String);
}

/// Связь тренер-клиент (см. backend trainer_clients) — единственный
/// источник истины о том, кто кому может видеть данные. Flutter здесь
/// только отображает статус, реальная проверка доступа всегда на backend.
class TrainerRelation {
  const TrainerRelation({
    required this.id,
    required this.trainerId,
    required this.clientId,
    required this.status,
    required this.sharePhotos,
    required this.counterpart,
  });

  final String id;
  final String trainerId;
  final String clientId;
  final TrainerRelationStatus status;
  final bool sharePhotos;
  final TrainerCounterpart? counterpart;

  factory TrainerRelation.fromJson(Map<String, dynamic> json) => TrainerRelation(
        id: json['id'] as String,
        trainerId: json['trainerId'] as String,
        clientId: json['clientId'] as String,
        status: TrainerRelationStatusX.fromApi(json['status'] as String),
        sharePhotos: json['sharePhotos'] as bool,
        counterpart: json['counterpart'] == null ? null : TrainerCounterpart.fromJson(json['counterpart'] as Map<String, dynamic>),
      );
}

/// "Coach Plan" + "Daily Target", которые клиент видит у себя.
class CoachPlan {
  const CoachPlan({required this.id, required this.trainerId, required this.title, required this.calorieTarget, required this.proteinTarget, required this.notes});

  final String id;
  final String trainerId;
  final String? title;
  final int? calorieTarget;
  final int? proteinTarget;
  final String? notes;

  factory CoachPlan.fromJson(Map<String, dynamic> json) => CoachPlan(
        id: json['id'] as String,
        trainerId: json['trainerId'] as String,
        title: json['title'] as String?,
        calorieTarget: (json['calorieTarget'] as num?)?.round(),
        proteinTarget: (json['proteinTarget'] as num?)?.round(),
        notes: json['notes'] as String?,
      );
}

/// "Assigned Meals" — назначенный рецепт (recipeId) или произвольный текстовый план.
class CoachMealAssignment {
  const CoachMealAssignment({
    required this.id,
    required this.trainerId,
    required this.recipeId,
    required this.title,
    required this.notes,
    required this.mealType,
    required this.createdAt,
  });

  final String id;
  final String trainerId;
  final String? recipeId;
  final String title;
  final String? notes;
  final String? mealType;
  final DateTime createdAt;

  factory CoachMealAssignment.fromJson(Map<String, dynamic> json) => CoachMealAssignment(
        id: json['id'] as String,
        trainerId: json['trainerId'] as String,
        recipeId: json['recipeId'] as String?,
        title: json['title'] as String,
        notes: json['notes'] as String?,
        mealType: json['mealType'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// "Coach Comments" — рекомендации и комментарии тренера.
class CoachComment {
  const CoachComment({required this.id, required this.trainerId, required this.message, required this.createdAt});

  final String id;
  final String trainerId;
  final String message;
  final DateTime createdAt;

  factory CoachComment.fromJson(Map<String, dynamic> json) => CoachComment(
        id: json['id'] as String,
        trainerId: json['trainerId'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
