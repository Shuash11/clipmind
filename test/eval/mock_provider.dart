import 'dart:async';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';

class MockLlmProvider implements LlmProvider {
  final Map<String, EditOperationSet> _responses = {};

  void addResponse(String command, EditOperationSet response) {
    _responses[command] = response;
  }

  @override
  String get id => 'mock-provider';

  @override
  Future<List<String>> availableModels() async => ['mock-model'];

  @override
  Future<EditOperationSet> parseCommand(AgentRequest request) async {
    final cmdLine = request.userCommand.split('---').first.trim();

    final exact = _responses[cmdLine];
    if (exact != null) return exact;

    final byLength = _responses.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in byLength) {
      if (cmdLine.startsWith(entry.key) || cmdLine.contains(entry.key)) {
        return entry.value;
      }
    }

    return const EditOperationSet(
      operations: [],
      summary: 'No matching mock response',
    );
  }

  @override
  Stream<ConnectionStatus> watchConnection() {
    return Stream.value(ConnectionStatus.connected);
  }
}
