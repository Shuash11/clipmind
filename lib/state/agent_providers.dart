import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/tool_calling_agent.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';
import 'package:clipmind/domain/agent/tools/tool_registry.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';

final ffmpegServiceProvider = Provider<FfmpegService>((ref) {
  return FfmpegService();
});

final ffprobeServiceProvider = Provider<FfprobeService>((ref) {
  return FfprobeService();
});

final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final registry = ProviderRegistry();
  ref.onDispose(() => registry.dispose());
  return registry;
});

final nl2vecPipelineProvider = Provider<Nl2VecPipeline>((ref) {
  final ffmpeg = ref.watch(ffmpegServiceProvider);
  final ffprobe = ref.watch(ffprobeServiceProvider);
  return Nl2VecPipeline(ffmpegService: ffmpeg, ffprobeService: ffprobe);
});

/// Live tool-execution context: reads the current project per call so the
/// agent edits against live ground truth (domain never imports state).
final toolContextProvider = Provider<ToolExecutionContext>((ref) {
  return ToolExecutionContext(
    project: () {
      final project = ref.read(projectProvider).valueOrNull;
      if (project == null) throw StateError('No project open.');
      return project;
    },
    outputDir: ref.read(projectProvider).valueOrNull?.outputDir ?? '',
    projectDir: ref.read(projectProvider).valueOrNull?.outputDir ?? '',
    applier: ref.read(agentEditApplierProvider),
    ffmpegService: ref.read(ffmpegServiceProvider),
    ffprobeService: ref.read(ffprobeServiceProvider),
  );
});

/// Registry with executors bound to the live context.
final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  return createToolRegistry(ref.read(toolContextProvider));
});

/// Tool-calling loop for one LLM provider (per-run instance via family).
final toolCallingAgentProvider =
    Provider.family<ToolCallingAgent, LlmProvider>((ref, provider) {
  final ctx = ref.read(toolContextProvider);
  return ToolCallingAgent(
    provider: provider,
    context: ctx,
    registry: createToolRegistry(ctx),
  );
});

/// ffprobe metadata for an arbitrary file path (cached per path).
final projectMetadataForPathProvider =
    FutureProvider.family<VideoMetadata?, String>((ref, path) async {
  if (path.trim().isEmpty) return null;
  return ref.watch(ffprobeServiceProvider).extractMetadata(path);
});

/// ffprobe metadata for the current project's first source file.
///
/// Cached by Riverpod; falls back to null when ffprobe is unavailable or
/// the project has no source file. Callers must treat null as unverified
/// and use safe defaults.
final projectMetadataProvider = FutureProvider<VideoMetadata?>((ref) async {
  final project = ref.watch(projectProvider).valueOrNull;
  if (project == null || project.sourceMediaPaths.isEmpty) return null;
  return ref.watch(ffprobeServiceProvider).extractMetadata(
        project.sourceMediaPaths.first,
      );
});

/// Single wiring point: AI edits -> ProjectNotifier + undo stack + DB/file.
final agentEditApplierProvider = Provider<AgentEditApplier>((ref) {
  return AgentEditApplier(
    onApply: (operation, newSourcePath) async {
      final project = ref.read(projectProvider).valueOrNull;
      ref.read(projectProvider.notifier).applyEdit(operation, newSourcePath);
      ref.read(undoRedoProvider.notifier).push(operation);
      if (project != null) {
        await ref
            .read(appDatabaseProvider)
            .saveEditOperation(project.id, operation);
        try {
          final updated = ref.read(projectProvider).valueOrNull;
          if (updated != null) {
            await ref.read(projectRepositoryProvider).save(updated);
          }
        } catch (_) {
          // File persistence is best-effort; in-memory + DB already updated.
        }
      }
    },
  );
});

final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier();
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super([]);

  void add(ChatMessage message) {
    state = [...state, message];
  }

  /// Convenience for agent replies carrying the applied operation IDs.
  void addAgentResult({
    required String id,
    required String content,
    required MessageStatus status,
    List<String> resultingOperationIds = const [],
  }) {
    add(ChatMessage(
      id: id,
      role: ChatRole.agent,
      content: content,
      timestamp: DateTime.now(),
      status: status,
      resultingOperationIds: resultingOperationIds,
    ));
  }

  void clear() {
    state = [];
  }
}
