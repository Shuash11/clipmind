import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';

final class ProviderPlatformBootstrapResult {
  ProviderPlatformBootstrapResult(
    this.registry, {
    Iterable<ProviderProfile> profiles = const <ProviderProfile>[],
    this.activeProfileId,
    this.schemaVersion = 1,
    this.legacyMigrationState = LegacyMigrationState.notStarted,
    this.repository,
    this.credentials,
  }) : profiles = List.unmodifiable(List<ProviderProfile>.from(profiles));

  final ProviderRegistry registry;
  final List<ProviderProfile> profiles;
  final String? activeProfileId;
  final int schemaVersion;
  final LegacyMigrationState legacyMigrationState;

  /// The durable instances that initialized this result. Keeping these in the
  /// runtime result prevents the management UI from creating a second store.
  final ProviderProfileRepository? repository;
  final CredentialStore? credentials;

  ProviderProfile? get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return null;
  }
}

abstract interface class ProviderPlatformBootstrap {
  Future<Result<ProviderPlatformBootstrapResult>> initialize({
    required bool networkEnabled,
  });
}
