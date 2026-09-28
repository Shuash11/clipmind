import 'package:clipmind/domain/agent/agent_turn.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';

enum ConnectionStatus { connected, disconnected, connecting, error }

abstract class LlmProvider {
  String get id;
  Future<List<String>> availableModels();
  Future<EditOperationSet> parseCommand(AgentRequest request);
  Stream<ConnectionStatus> watchConnection();

  /// Whether this provider supports native tool calling.
  ///
  /// OpenAI, Anthropic, and Ollama (via its OpenAI-compatible `/v1`
  /// endpoint) override this. The pipeline routes to [ToolCallingAgent]
  /// when true, else the legacy one-shot stage path.
  bool get supportsToolCalling => false;

  /// One API round trip with tools (D1: transport-only, no loop).
  ///
  /// Throws [UnimplementedError] by default.
  Future<AgentTurnResult> chatWithTools(AgentTurnRequest request) {
    throw UnimplementedError('$id does not support tool calling.');
  }
}
