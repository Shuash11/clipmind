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
