import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';

/// Whether [profile]'s provider can list models from its remote catalog.
///
/// Mirrors the private `ProviderProfileNotifier._supportsDiscovery` check so
/// widgets gate auto-discovery on the exact same contract the notifier
/// enforces: the custom OpenAI-compatible provider always supports discovery,
/// presets only when their definition declares it.
bool modelDiscoverySupported(ProviderRegistry registry, ProviderProfile profile) =>
    profile.providerId == customOpenAiCompatibleProviderId ||
    (registry.definitionFor(profile.providerId)?.modelDiscoveryIsAvailable ??
        false);
