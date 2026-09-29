import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/data/models/chat_step.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/ffmpeg/procedural_sound_service.dart';
import 'package:clipmind/data/services/fonts/font_resolver.dart';
import 'package:clipmind/data/services/llm/provider_registry.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart'
    hide providerRegistryProvider;
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';

final ffmpegServiceProvider = Provider<FfmpegService>((ref) {
  return FfmpegService();
});

final ffprobeServiceProvider = Provider<FfprobeService>((ref) {
  return FfprobeService();
});

/// Bundled-font resolution for the CapCut-style text panel (Cycle 5
/// Phase 3): `FontResolver` extracts `assets/fonts/` entries to the
/// app-support directory on first use and caches the `.ttf` paths.
/// Override in tests with an injected temp-dir + in-memory asset loader.
final fontResolverProvider = Provider<FontResolver>((ref) {
  return FontResolver();
});

/// Procedural sound generation for the CapCut-style sound panel:
/// `ProceduralSoundService` renders the 6 lavfi presets to temp wavs that
/// feed the `add_sound` op's `sound_path`. Override in tests via the
/// `runProcess` seam (or by subclassing `generate`).
final proceduralSoundServiceProvider = Provider<ProceduralSoundService>(
  (ref) {
    return ProceduralSoundService();
  },
);

/// The `ToolExecutionContext.resolveFont` callback, wired to
/// [fontResolverProvider] (mirrors the `readAnalysis`/`whisperConfig`
/// wiring pattern: state owns the getter, domain consumes the callback).
/// Pass this wherever a tool context is constructed so the agent loop's
/// `overlay_text` `font` arg resolves exactly like the panel path.
final resolveFontProvider = Provider<Future<String?> Function(String)>(
  (ref) {
    final resolver = ref.watch(fontResolverProvider);
    return resolver.resolve;
  },
);

/// Gen A registry wired to the live Gen B profile system.
///
/// The resolver reads the active profile (id, endpoint, credential,
/// selected model) on every [getActiveProvider] call; resolved providers
/// are cached by the registry, so any profile change (activation, model
/// select, enable/disable) invalidates via [ProviderRegistry.invalidateActive].
/// Resolver failure falls through to the legacy path (never throws here).
final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final registry = ProviderRegistry(
    activeProfileResolver: () async {
      final state = ref.read(providerProfileNotifierProvider);
      final profile = state.activeProfile;
      if (profile == null || !state.hasUsableActiveProfile) return null;
      String? apiKey;
      final credentialId = profile.credentialId;
      if (credentialId != null) {
        try {
          final result = await ref
              .read(providerCredentialStoreProvider)
              .read(credentialId);
          if (result case Success<String?>(:final value)) apiKey = value;
        } catch (_) {}
      }
      // profile.endpoint is draft-validated (full host:port URI); apiKey
      // '' preserves each provider's own keystore fallback. Never logged.
      return ActiveLlmConfig(
        providerId: profile.providerId,
        endpoint: profile.endpoint,
        apiKey: apiKey ?? '',
        model: profile.selectedModelId,
      );
    },
  );
  ref.listen(
    providerProfileNotifierProvider,
    (_, _) => registry.invalidateActive(),
  );
  ref.onDispose(() => registry.dispose());
  return registry;
});

final nl2vecPipelineProvider = Provider<Nl2VecPipeline>((ref) {
  final ffmpeg = ref.watch(ffmpegServiceProvider);
  final ffprobe = ref.watch(ffprobeServiceProvider);
  return Nl2VecPipeline(ffmpegService: ffmpeg, ffprobeService: ffprobe);
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
    onApply: (operation, newSourcePath, {List<String> removeClipIds = const []}) async {
      // Memento order: snapshot first, then mutate. Guarded: no project
      // means nothing to snapshot (and nothing to apply to).
      final project = ref.read(projectProvider).valueOrNull;
      if (project != null) {
        ref.read(undoRedoProvider.notifier).pushEdit(project, operation);
      }
      ref.read(projectProvider.notifier).applyEdit(
            operation,
            newSourcePath,
            removeClipIds: removeClipIds,
          );
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

  /// Replace in-memory history (used by `loadHistory` on project open).
  void replaceAll(List<ChatMessage> messages) {
    state = [...messages];
  }

  /// Convenience for agent replies carrying the applied operation IDs.
  void addAgentResult({
    required String id,
    required String content,
    required MessageStatus status,
    List<String> resultingOperationIds = const [],
    List<ChatStep> steps = const [],
  }) {
    add(ChatMessage(
      id: id,
      role: ChatRole.agent,
      content: content,
      timestamp: DateTime.now(),
      status: status,
      resultingOperationIds: resultingOperationIds,
      steps: steps,
    ));
  }

  void clear() {
    state = [];
  }
}

