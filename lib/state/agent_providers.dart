import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/models/chat_message.dart';

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
      return ChatMessagesNotifier();
    });

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super([]);

  void add(ChatMessage message) {
    state = [...state, message];
  }

  void clear() {
    state = [];
  }
}
