import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/llm/openai_compatible_provider.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/state/agent_providers.dart';

/// Resolver used by [ffmpegBinaryAvailableProvider] (overridable in tests).
final ffmpegBinaryResolverProvider = Provider<FfmpegBinaryResolver>((ref) {
  return FfmpegBinaryResolver();
});

/// Health of the active LLM provider, resolved from the same Gen A
/// [providerRegistryProvider] the run path uses.
///
/// Never throws: with no active provider (or a failing lookup/stream) it
/// emits [ConnectionStatus.disconnected]. Rebuilds when the registry
/// changes and on profile activation/usable changes only (narrow select —
/// loading/saving/discovering do not resubscribe); each rebuild
/// re-subscribes (providers cancel prior health timers per
/// `watchConnection()` call).
final providerHealthProvider = StreamProvider<ConnectionStatus>((ref) async* {
  ref.watch(
    providerProfileNotifierProvider.select(
      (s) => (s.activeProfileId, s.hasUsableActiveProfile),
    ),
  );
  LlmProvider? provider;
  try {
    provider =
        await ref.watch(providerRegistryProvider).getActiveProvider();
  } catch (_) {
    provider = null;
  }
  if (provider == null) {
    yield ConnectionStatus.disconnected;
    return;
  }
  try {
    yield* provider.watchConnection();
  } catch (_) {
    yield ConnectionStatus.disconnected;
  }
});

/// Whether an FFmpeg binary is available on this machine.
///
/// Never throws in build: resolver failure reads as unavailable.
final ffmpegBinaryAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    return ref.watch(ffmpegBinaryResolverProvider).resolveFfmpeg() != null;
  } catch (_) {
    return false;
  }
});

/// The active provider's resolved model name (same registry the run path
/// uses) — for the status bar's model pill.
///
/// Rebuilds only on profile/model selection changes (narrow select); the
/// registry's `ref.listen` → `invalidateActive` makes each rebuild resolve
/// fresh, so model changes flow through. Only OpenAI-compatible providers
/// expose a model name — native Gemini/Anthropic return null and the
/// frontend keeps the plain label. Never throws in build.
final resolvedModelNameProvider = FutureProvider<String?>((ref) async {
  ref.watch(
    providerProfileNotifierProvider.select(
      (s) => (
        s.activeProfileId,
        s.hasUsableActiveProfile,
        s.selectedModelId,
      ),
    ),
  );
  try {
    final provider =
        await ref.watch(providerRegistryProvider).getActiveProvider();
    if (provider is OpenAiCompatibleLlmProvider) {
      return provider.modelName;
    }
    return null;
  } catch (_) {
    return null;
  }
});
