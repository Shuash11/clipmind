import 'package:clipmind/domain/agent/operation_schema.dart';

enum ConnectionStatus { connected, disconnected, connecting, error }

abstract class LlmProvider {
  String get id;
  Future<List<String>> availableModels();
  Future<EditOperationSet> parseCommand(AgentRequest request);
  Stream<ConnectionStatus> watchConnection();
}
