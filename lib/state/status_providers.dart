import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
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
/// changes; each rebuild re-subscribes (providers cancel prior health
/// timers per `watchConnection()` call).
final providerHealthProvider = StreamProvider<ConnectionStatus>((ref) async* {
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
