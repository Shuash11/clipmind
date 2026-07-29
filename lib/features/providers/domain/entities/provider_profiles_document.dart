import 'provider_profile.dart';

final class ProviderProfilesDocument {
  factory ProviderProfilesDocument({
    required int schemaVersion,
    required Iterable<ProviderProfile> profiles,
    String? activeProfileId,
    LegacyMigrationState legacyMigrationState = LegacyMigrationState.notStarted,
  }) {
    final copiedProfiles = List<ProviderProfile>.from(profiles);
    return ProviderProfilesDocument._(
      schemaVersion: schemaVersion,
      profiles: copiedProfiles,
      activeProfileId: activeProfileId,
      legacyMigrationState: legacyMigrationState,
    );
  }

  ProviderProfilesDocument._({
    required this.schemaVersion,
    required List<ProviderProfile> profiles,
    required String? activeProfileId,
    required this.legacyMigrationState,
  }) : profiles = List.unmodifiable(profiles),
       activeProfileId = _resolvedActiveProfileId(activeProfileId, profiles);

  final int schemaVersion;
  final List<ProviderProfile> profiles;

  /// Null unless it selects an enabled, non-pending profile in [profiles].
  final String? activeProfileId;
  final LegacyMigrationState legacyMigrationState;

  ProviderProfile? get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return null;
  }

  ProviderProfilesDocument withProfiles(
    Iterable<ProviderProfile> value, {
    String? activeProfileId,
    LegacyMigrationState? legacyMigrationState,
  }) => ProviderProfilesDocument(
    schemaVersion: schemaVersion,
    profiles: value,
    activeProfileId: activeProfileId ?? this.activeProfileId,
    legacyMigrationState: legacyMigrationState ?? this.legacyMigrationState,
  );

  static String? _resolvedActiveProfileId(
    String? proposed,
    Iterable<ProviderProfile> profiles,
  ) {
    if (proposed == null) return null;
    for (final profile in profiles) {
      if (profile.id == proposed &&
          profile.enabled &&
          !profile.deletionPending) {
        return proposed;
      }
    }
    return null;
  }
}

enum LegacyMigrationState { notStarted, pending, completed }
