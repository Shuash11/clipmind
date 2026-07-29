import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/catalog/provider_catalog.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/data/network_disabled_provider_http_transport.dart';
import 'package:clipmind/features/providers/data/provider_registry_impl.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_profile_repository.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profiles_document.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';

typedef ProviderMigrationRunner = Future<Result<void>> Function();
typedef ProviderRegistryFactory =
    ProviderRegistry Function(ProviderHttpTransport transport);

/// Deterministic metadata-only platform initialization. It never discovers,
/// tests, or completes against a provider.
final class ProviderPlatformBootstrapImpl implements ProviderPlatformBootstrap {
  factory ProviderPlatformBootstrapImpl({
    required ProviderProfileRepository profiles,
    required CredentialStore credentials,
    required ProviderMigrationRunner migrate,
    required ProviderHttpTransport transport,
    ProviderRegistryFactory? registryFactory,
    Iterable<ProviderDefinition>? definitions,
  }) => ProviderPlatformBootstrapImpl._(
    profiles,
    credentials,
    migrate,
    transport,
    registryFactory,
    definitions,
  );

  ProviderPlatformBootstrapImpl._(
    this._profiles,
    this._credentials,
    this._migrate,
    this._transport,
    ProviderRegistryFactory? registryFactory,
    Iterable<ProviderDefinition>? definitions,
  ) : _registryFactory =
          registryFactory ??
          ((activeTransport) => ProviderRegistryImpl.standard(
            transport: activeTransport,
            credentials: _credentials,
            definitions: definitions ?? ProviderCatalog.presets,
          ));

  final ProviderProfileRepository _profiles;
  final CredentialStore _credentials;
  final ProviderMigrationRunner _migrate;
  final ProviderHttpTransport _transport;
  final ProviderRegistryFactory _registryFactory;
  final Map<bool, ProviderRegistry> _registries = <bool, ProviderRegistry>{};
  bool _migrationCompleted = false;

  @override
  Future<Result<ProviderPlatformBootstrapResult>> initialize({
    required bool networkEnabled,
  }) async {
    try {
      // 1-2. Catalog is captured by the registry factory and metadata loads first.
      final initial = await _profiles.load();
      if (initial is Failure<ProviderProfilesDocument>) {
        return _fail(initial.error);
      }
      // 3. Pending cleanup is durable and must precede migration.
      final resumed = await _profiles.resumePendingDeletions(_credentials);
      if (resumed is Failure<void>) return _fail(resumed.error);
      // 4. The migration itself is idempotent and records a pending state.
      if (!_migrationCompleted) {
        final migrated = await _migrate();
        if (migrated is Failure<void>) return _fail(migrated.error);
        _migrationCompleted = true;
      }
      // 5. Adapters are built once per composition mode, before active selection.
      final registry = _registries.putIfAbsent(
        networkEnabled,
        () => _registryFactory(
          networkEnabled
              ? _transport
              : const NetworkDisabledProviderHttpTransport(),
        ),
      );
      // 6. Resolve only final durable profile metadata.
      final finalDocument = await _profiles.load();
      if (finalDocument is Failure<ProviderProfilesDocument>) {
        return _fail(finalDocument.error);
      }
      final document =
          (finalDocument as Success<ProviderProfilesDocument>).value;
      return Success<ProviderPlatformBootstrapResult>(
        ProviderPlatformBootstrapResult(
          registry,
          profiles: document.profiles,
          activeProfileId: document.activeProfileId,
          schemaVersion: document.schemaVersion,
          legacyMigrationState: document.legacyMigrationState,
          repository: _profiles,
          credentials: _credentials,
        ),
      );
    } catch (_) {
      return _fail(const ProviderRegistryFailure());
    }
  }

  Result<ProviderPlatformBootstrapResult> _fail(Object error) {
    final failure = error is AppFailure
        ? error
        : const ProviderRegistryFailure();
    return Failure<ProviderPlatformBootstrapResult>(failure);
  }
}
