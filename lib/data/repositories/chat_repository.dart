import 'dart:async';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/local/database/app_database.dart';

class ChatRepository {
  final AppDatabase _db;
  final List<ChatMessage> _messages = [];
  final _controller = StreamController<List<ChatMessage>>.broadcast();

  ChatRepository(this._db);

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Stream<List<ChatMessage>> get stream => _controller.stream;

  Future<void> add(ChatMessage message, {String? projectId}) async {
    _messages.add(message);
    if (projectId != null) {
      await _db.saveChatMessage(projectId, message);
    }
    _controller.add(List.unmodifiable(_messages));
  }

  Future<void> getHistory(String projectId) async {
    final msgs = await _db.getChatMessages(projectId);
    _messages
      ..clear()
      ..addAll(msgs);
    _controller.add(List.unmodifiable(_messages));
  }

  List<ChatMessage> recent(int count) {
    return _messages.length <= count
        ? List.from(_messages)
        : _messages.sublist(_messages.length - count);
  }

  Future<void> clear({String? projectId}) async {
    _messages.clear();
    _controller.add(List.unmodifiable(_messages));
    if (projectId != null) {
      await _db.deleteChatMessages(projectId);
    }
  }

  void dispose() {
    _controller.close();
  }
}
