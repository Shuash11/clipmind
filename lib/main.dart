import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app.dart';
import 'core/results/result.dart';
import 'core/runtime/foundation_composition.dart';
import 'features/providers/data/provider_platform_riverpod.dart';
import 'features/providers/data/provider_platform_startup.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final preparation = await FoundationComposition(
    providerInitializer: const ProviderPlatformStartupBootstrap(),
  ).prepare(arguments);
  if (preparation case Failure<FoundationPreparation>(:final error)) {
    debugPrint(error.message);
    return;
  }
  final foundation = (preparation as Success<FoundationPreparation>).value;
  runApp(
    ProviderScope(
      // Preserves Riverpod 2.x behavior (3.x enables automatic retry by
      // default with exponential backoff). Decision (Cycle 7 Phase 2):
      // keep the global kill-switch — ffprobe/DB failures are environmental
      // (missing binary → null, not throw) and the status/health providers
      // never throw, so automatic retry has no benefit; `provider.future`
      // also skips intermediate error states while retrying, which would
      // stall the agent run's metadata await.
      retry: (retryCount, error) => null,
      overrides: [
        providerPlatformBootstrapResultProvider.overrideWithValue(
          foundation.providerInitialization,
        ),
      ],
      child: ClipMindApp(
        localSmokeConfiguration: foundation.localSmokeConfiguration,
      ),
    ),
  );
}
