import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mock/mock_trainers.dart';
import '../models/trainer.dart';

final trainersProvider = Provider<List<Trainer>>((ref) => mockTrainers);
final myTrainerProvider = Provider<Trainer>((ref) => myTrainer);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super(mockChatMessages);

  void send(String text) {
    state = [
      ...state,
      ChatMessage(sender: MessageSender.user, text: text, time: _now()),
    ];
  }

  static String _now() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) => ChatNotifier());
