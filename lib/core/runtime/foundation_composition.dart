import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/runtime/local_smoke_launch_configuration.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';

final class FoundationComposition {
  factory FoundationComposition({
    required ProviderPlatformBootstrap providerInitializer,
  }) => FoundationComposition._(providerInitializer);

  FoundationComposition._(this._providerInitializer);

  final ProviderPlatformBootstrap _providerInitializer;

  Future<Result<FoundationPreparation>> prepare(List<String> arguments) async {
    LocalSmokeLaunchConfiguration? localSmokeConfiguration;
    if (arguments.isNotEmpty) {
      final parsed = LocalSmokeLaunchConfiguration.parse(arguments);
      if (parsed case Failure<LocalSmokeLaunchConfiguration>(:final error)) {
        return Failure<FoundationPreparation>(error);
      }
      localSmokeConfiguration =
          (parsed as Success<LocalSmokeLaunchConfiguration>).value;
    }

    Result<ProviderPlatformBootstrapResult> providerInitialization;
    try {
      providerInitialization = await _providerInitializer.initialize(
        networkEnabled: localSmokeConfiguration == null,
      );
    } catch (_) {
      providerInitialization = const Failure<ProviderPlatformBootstrapResult>(
        ProviderPersistenceFailure(
          'Provider platform initialization could not be completed.',
        ),
      );
    }
    return Success<FoundationPreparation>(
      FoundationPreparation(
        localSmokeConfiguration: localSmokeConfiguration,
        providerInitialization: providerInitialization,
      ),
    );
  }
}

final class FoundationPreparation {
  const FoundationPreparation({
    required this.localSmokeConfiguration,
    required this.providerInitialization,
  });

  final LocalSmokeLaunchConfiguration? localSmokeConfiguration;
  final Result<ProviderPlatformBootstrapResult> providerInitialization;
}
