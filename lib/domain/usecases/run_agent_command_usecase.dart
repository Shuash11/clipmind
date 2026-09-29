import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/transcription/whisper_service.dart';
import 'package:clipmind/domain/agent/agent_confirmation.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';

/// Single entry point from the state layer into the Gen A tool path.
///
/// Thin wrapper over [Nl2VecPipeline.submitCommand] (which owns the
/// capability gate); constructed in app code by [AgentRunController].
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
    Project Function()? liveProject,
    CancellationToken? cancellation,
    ConfirmationGate? gate,
    bool dryRun = false,
    // Tool-context wiring — see [Nl2VecPipeline.submitCommand] for the
    // state-side sources (agentAnalysisPortProvider / settingsProvider /
    // resolveFontProvider). All optional (null = executor degradation).
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) {
    return _pipeline.submitCommand(
      command,
      project,
      provider: provider,
      metadata: metadata,
      recentHistory: recentHistory,
      applier: applier,
      liveProject: liveProject,
      cancellation: cancellation,
      gate: gate,
      dryRun: dryRun,
      readAnalysis: readAnalysis,
      writeAnalysis: writeAnalysis,
      whisperConfig: whisperConfig,
      resolveFont: resolveFont,
    );
  }

  /// Deterministic replay of dry-run planned calls (Phase 6d).
  ///
  /// [planned] are the edit-tool [ToolCall]s recorded during a dry-run
  /// planning pass (rebuilt from the run's successful edit-tool records:
  /// `ToolCall(id: record.id, name: record.name, args: record.args)`).
  Future<SubmitResult> executePlanned(
    List<ToolCall> planned,
    Project project, {
    AgentEditApplier? applier,
    Project Function()? liveProject,
    CancellationToken? cancellation,
    // Same wiring as [execute]; replay only runs edit tools so
    // `resolveFont` is the one that matters (`overlay_text` `font` arg).
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) {
    return _pipeline.executePlanned(
      planned,
      project,
      applier: applier,
      liveProject: liveProject,
      cancellation: cancellation,
      readAnalysis: readAnalysis,
      writeAnalysis: writeAnalysis,
      whisperConfig: whisperConfig,
      resolveFont: resolveFont,
    );
  }
}
