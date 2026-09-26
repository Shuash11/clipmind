import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'package:clipmind/features/providers/data/catalog/provider_catalog.dart';
import 'package:clipmind/features/providers/data/policy/provider_url_policy.dart';
import 'package:clipmind/features/providers/data/security/secure_credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';

final class LegacyProviderSettings {
  const LegacyProviderSettings({
    required this.activeProviderId,
    required this.activeModel,
    required this.ollamaEndpoint,
  });

  final String? activeProviderId;
  final String? activeModel;
  final String? ollamaEndpoint;
}

abstract interface class LegacyProviderSettingsSource {
  Future<Result<LegacyProviderSettings?>> load();
}

abstract interface class LegacyProviderCredentialSource {
  Future<Result<String?>> readApiKey(String providerId);
  Future<Result<void>> deleteApiKey(String providerId);
}

/// Production adapter that reads only the legacy settings fields needed here.
final class AppSettingsLegacyProviderSettingsSource
    implements LegacyProviderSettingsSource {
  AppSettingsLegacyProviderSettingsSource(this._settings);

  final SettingsRepository _settings;

  @override
  Future<Result<LegacyProviderSettings?>> load() async {
    try {
      final AppSettings settings = await _settings.load();
      return Success<LegacyProviderSettings?>(
        LegacyProviderSettings(
          activeProviderId: settings.activeProviderId,
          activeModel: settings.activeModel,
          ollamaEndpoint: settings.ollamaEndpoint,
        ),
      );
    } catch (_) {
      return const Failure<LegacyProviderSettings?>(ProviderMigrationFailure());
    }
  }
}

/// Legacy key adapter. It scopes every operation to one catalog provider and
/// deliberately has no clear-all operation.
final class LegacySecureCredentialSource
    implements LegacyProviderCredentialSource {
  LegacySecureCredentialSource({SecureStorageBackend? backend})
    : _backend = backend ?? FlutterSecureStorageBackend();

  final SecureStorageBackend _backend;

  @override
  Future<Result<void>> deleteApiKey(String providerId) async {
    final key = _keyFor(providerId);
    if (key == null) return const Failure<void>(ProviderMigrationFailure());
    try {
      await _backend.delete(key: key);
      return const Success<void>(null);
    } catch (_) {
      return const Failure<void>(ProviderMigrationFailure());
    }
  }

  @override
  Future<Result<String?>> readApiKey(String providerId) async {
    final key = _keyFor(providerId);
    if (key == null) return const Failure<String?>(ProviderMigrationFailure());
    try {
      return Success<String?>(await _backend.read(key: key));
    } catch (_) {
      return const Failure<String?>(ProviderMigrationFailure());
    }
  }

  String? _keyFor(String providerId) => ProviderCatalog.byId(providerId) == null
      ? null
      : 'clipmind_${providerId}_api_key';
}

/// Idempotently imports legacy settings and provider-name credentials into the
/// profile platform. New metadata is durable before a legacy key is removed.
final class LegacyProviderSettingsMigration {
  factory LegacyProviderSettingsMigration({
    required ProviderProfileRepository repository,
    required LegacyProviderSettingsSource settings,
    required LegacyProviderCredentialSource legacyCredentials,
    required CredentialStore credentials,
  }) => LegacyProviderSettingsMigration._(
    repository,
    settings,
    legacyCredentials,
    credentials,
  );

  LegacyProviderSettingsMigration._(
    this._repository,
    this._settings,
    this._legacyCredentials,
    this._credentials,
  );

  final ProviderProfileRepository _repository;
  final LegacyProviderSettingsSource _settings;
  final LegacyProviderCredentialSource _legacyCredentials;
  final CredentialStore _credentials;

  Future<Result<void>> migrate() async {
    try {
      return await _migrate();
    } catch (_) {
      return _failure();
    }
  }

  Future<Result<void>> _migrate() async {
    final settingsResult = await _settings.load();
    if (settingsResult is Failure<LegacyProviderSettings?>) return _failure();
    final legacy = (settingsResult as Success<LegacyProviderSettings?>).value;
    final documentResult = await _repository.load();
    if (documentResult is Failure<ProviderProfilesDocument>) return _failure();
    var document = (documentResult as Success<ProviderProfilesDocument>).value;
    if (document.legacyMigrationState == LegacyMigrationState.completed) {
      return const Success<void>(null);
    }

    // A pending state makes every later interruption explicitly resumable.
    document = _document(document, migration: LegacyMigrationState.pending);
    final pendingSave = await _repository.save(document);
    if (pendingSave is Failure<void>) return _failure();
    if (legacy == null) return _complete(document, null);

    String? migratedActiveProfileId;
    for (final definition in ProviderCatalog.presets) {
      final legacyCredential = await _legacyCredentials.readApiKey(
        definition.id,
      );
      if (legacyCredential is Failure<String?>) return _failure();
      final secret = (legacyCredential as Success<String?>).value;
      final isActive = legacy.activeProviderId == definition.id;
      if (!isActive && (secret == null || secret.isEmpty)) continue;

      final profileId = 'legacy-${definition.id}';
      if (isActive) migratedActiveProfileId = profileId;
      if (!document.profiles.any((profile) => profile.id == profileId)) {
        final profile = _profile(definition, legacy, isActive);
        if (profile == null) return _failure();
        document = _document(
          document,
          profiles: <ProviderProfile>[...document.profiles, profile],
        );
        final profileSave = await _repository.save(document);
        if (profileSave is Failure<void>) return _failure();
      }

      if (secret != null && secret.isNotEmpty) {
        final scopedKey = SecureCredentialStore.apiKeyCredentialId(profileId);
        final copied = await _credentials.write(scopedKey, secret);
        if (copied is Failure<void>) return _failure();
        // The profile was saved above, so this cannot lose the only copy.
        final removed = await _legacyCredentials.deleteApiKey(definition.id);
        if (removed is Failure<void>) return _failure();
      }
    }
    return _complete(document, migratedActiveProfileId);
  }

  ProviderProfile? _profile(
    ProviderDefinition definition,
    LegacyProviderSettings settings,
    bool isActive,
  ) {
    var endpoint = definition.baseUri;
    if (definition.id == 'ollama' && settings.ollamaEndpoint != null) {
      final validated = ProviderUrlPolicy.parseAndValidate(
        settings.ollamaEndpoint!,
      );
      if (validated is Failure<ProviderUrlValidation>) return null;
      endpoint = (validated as Success<ProviderUrlValidation>).value.uri;
    }
    return ProviderProfile(
      id: 'legacy-${definition.id}',
      providerId: definition.id,
      displayName: definition.displayName,
      endpoint: endpoint,
      credentialId: SecureCredentialStore.apiKeyCredentialId(
        'legacy-${definition.id}',
      ),
      manualModelIds:
          isActive &&
              settings.activeModel != null &&
              settings.activeModel!.isNotEmpty
          ? <String>[settings.activeModel!]
          : const <String>[],
    );
  }

  Future<Result<void>> _complete(
    ProviderProfilesDocument document,
    String? activeProfileId,
  ) async {
    final completed = _document(
      document,
      activeProfileId: activeProfileId,
      migration: LegacyMigrationState.completed,
    );
    final saved = await _repository.save(completed);
    return saved is Failure<void> ? _failure() : const Success<void>(null);
  }

  ProviderProfilesDocument _document(
    ProviderProfilesDocument current, {
    Iterable<ProviderProfile>? profiles,
    String? activeProfileId,
    LegacyMigrationState? migration,
  }) => ProviderProfilesDocument(
    schemaVersion: current.schemaVersion,
    profiles: profiles ?? current.profiles,
    activeProfileId: activeProfileId ?? current.activeProfileId,
    legacyMigrationState: migration ?? current.legacyMigrationState,
  );

  Failure<void> _failure() => const Failure<void>(ProviderMigrationFailure());
}
