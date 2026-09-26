import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';

class RunAgentCommandUseCase {
  final Nl2VecPipeline _pipeline;

  RunAgentCommandUseCase(this._pipeline);

  Future<SubmitResult> execute(
    String command,
    Project project, {
    LlmProvider? provider,
    VideoMetadata? metadata,
    List<AgentRequest>? recentHistory,
    AgentEditApplier? applier,
  }) {
    return _pipeline.submitCommand(
      command,
      project,
      provider: provider,
      metadata: metadata,
      recentHistory: recentHistory,
      applier: applier,
    );
  }
}
