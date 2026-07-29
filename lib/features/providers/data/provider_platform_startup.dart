import 'dart:io';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/data/migration/legacy_provider_settings_migration.dart';
import 'package:clipmind/features/providers/data/profiles/provider_profiles_storage.dart';
import 'package:clipmind/features/providers/data/provider_platform_bootstrap_impl.dart';
import 'package:clipmind/features/providers/data/provider_profile_repository_impl.dart';
import 'package:clipmind/features/providers/data/security/secure_credential_store.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Transitional application composition only. Provider protocol code remains
/// independent of the legacy settings source used by the one-time migration.
final class ProviderPlatformStartup {
  ProviderPlatformStartup._();

  static Future<Result<ProviderPlatformBootstrapResult>> initialize({
    bool networkEnabled = true,
  }) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final profiles = ProviderProfileRepositoryImpl(
        storage: FileProviderProfilesStorage(
          File(
            '${directory.path}${Platform.pathSeparator}provider_profiles.json',
          ),
        ),
      );
      final credentials = SecureCredentialStore();
      final migration = LegacyProviderSettingsMigration(
        repository: profiles,
        settings: AppSettingsLegacyProviderSettingsSource(SettingsRepository()),
        legacyCredentials: LegacySecureCredentialSource(),
        credentials: credentials,
      );
      final bootstrap = ProviderPlatformBootstrapImpl(
        profiles: profiles,
        credentials: credentials,
        migrate: migration.migrate,
        transport: DioProviderHttpTransport(dio: Dio()),
      );
      return bootstrap.initialize(networkEnabled: networkEnabled);
    } catch (_) {
      return const Failure<ProviderPlatformBootstrapResult>(
        ProviderPersistenceFailure(
          'Provider platform initialization could not be started.',
        ),
      );
    }
  }
}

final class ProviderPlatformStartupBootstrap
    implements ProviderPlatformBootstrap {
  const ProviderPlatformStartupBootstrap();

  @override
  Future<Result<ProviderPlatformBootstrapResult>> initialize({
    required bool networkEnabled,
  }) => ProviderPlatformStartup.initialize(networkEnabled: networkEnabled);
}
