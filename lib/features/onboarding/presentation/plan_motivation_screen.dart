import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/mascot_encouragement_screen.dart';

class PlanMotivationScreen extends StatelessWidget {
  const PlanMotivationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MascotEncouragementScreen(
      progress: 0.85,
      title: 'Не останавливайся,\nстановясь сильнее!',
      body: 'В жизни всегда есть взлёты и падения, но у тебя есть силы довести дело до конца. Здорово, что ты продолжаешь свой путь!',
      buttonLabel: 'Далее',
      onNext: () => context.pushReplacement('/plan-ready'),
    );
  }
}
