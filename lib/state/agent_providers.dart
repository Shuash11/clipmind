import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
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
  return Nl2VecPipeline(ffmpegService: ffmpeg);
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
