import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trainer.dart';

class AiAssistantNotifier extends StateNotifier<List<ChatMessage>> {
  AiAssistantNotifier()
      : super([
          ChatMessage(sender: MessageSender.ai, text: 'Привет! Я AI-ассистент RAZVIT 🐻 Спроси про тренировки, питание, мотивацию или сон — помогу!', time: _now()),
        ]);

  void send(String text) {
    state = [...state, ChatMessage(sender: MessageSender.user, text: text, time: _now())];
    final reply = _reply(text.toLowerCase());
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      state = [...state, ChatMessage(sender: MessageSender.ai, text: reply, time: _now())];
    });
  }

  String _reply(String text) {
    if (text.contains('тренир') || text.contains('упражнен')) {
      return 'Загляни во вкладку «Тренировки» — там твоя программа на сегодня. Если пропустил день, просто продолжи с того же места, не начинай сначала 💪';
    }
    if (text.contains('питан') || text.contains('еда') || text.contains('калор') || text.contains('бжу')) {
      return 'Держи баланс БЖУ из своего плана в разделе «Питание». Если сорвался — не страшно, следующий приём пищи просто по плану, без самобичевания 🥗';
    }
    if (text.contains('вод')) {
      return 'Норма воды есть на главном экране — старайся пить понемногу в течение дня, а не всё разом 💧';
    }
    if (text.contains('сон') || text.contains('спать') || text.contains('устал')) {
      return 'Восстановление важно не меньше тренировок — старайся спать 7-8 часов, иначе прогресс будет медленнее 😴';
    }
    if (text.contains('лень') || text.contains('не хочу') || text.contains('мотивац')) {
      return 'Бывает! Начни хотя бы с разминки на 5 минут — часто этого достаточно, чтобы втянуться. Ты уже прошёл больше, чем тебе кажется 🔥';
    }
    if (text.contains('привет') || text.contains('здрав')) {
      return 'Привет-привет! Чем могу помочь сегодня?';
    }
    if (text.contains('спасибо')) {
      return 'Всегда пожалуйста! Я рядом 🐻';
    }
    return 'Я пока учусь отвечать на такие вопросы, но по тренировкам, питанию, воде и мотивации — всегда готов помочь!';
  }

  static String _now() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

final aiAssistantProvider = StateNotifierProvider<AiAssistantNotifier, List<ChatMessage>>((ref) => AiAssistantNotifier());
