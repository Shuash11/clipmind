import 'dart:io';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/runtime/foundation_composition.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/contracts/provider_registry.dart';
import 'package:clipmind/features/providers/domain/entities/provider_definition.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

int _pathSequence = 0;

void main() {
  test(
    'initializes providers once with networking for a normal launch',
    () async {
      final initializer = _RecordingProviderInitializer();
      final composition = FoundationComposition(
        providerInitializer: initializer,
      );

      final Result<FoundationPreparation> prepared = await composition.prepare(
        const <String>[],
      );

      expect(prepared, isA<Success<FoundationPreparation>>());
      final value = (prepared as Success<FoundationPreparation>).value;
      expect(value.localSmokeConfiguration, isNull);
      expect(value.providerInitialization, same(initializer.result));
      expect(initializer.networkEnabled, <bool>[true]);
    },
  );

  test('valid local smoke launch disables provider networking once', () async {
    final fixture = await _unusedSystemTempFile('.cmproj');
    final report = await _unusedSystemTempFile('.json');
    addTearDown(() => _deleteIfPresent(fixture));
    addTearDown(() => _deleteIfPresent(report));
    await fixture.writeAsString('{"project":"smoke"}', flush: true);
    final initializer = _RecordingProviderInitializer();
    final composition = FoundationComposition(providerInitializer: initializer);

    final Result<FoundationPreparation> prepared = await composition
        .prepare(<String>[
          '--clipmind-local-smoke',
          '--fixture=${fixture.path}',
          '--report=${report.path}',
        ]);

    expect(prepared, isA<Success<FoundationPreparation>>());
    final value = (prepared as Success<FoundationPreparation>).value;
    expect(value.localSmokeConfiguration, isNotNull);
    expect(
      value.localSmokeConfiguration!.fixture.absolute.path,
      fixture.absolute.path,
    );
    expect(
      value.localSmokeConfiguration!.report.absolute.path,
      report.absolute.path,
    );
    expect(initializer.networkEnabled, <bool>[false]);
  });

  test(
    'invalid local smoke arguments fail before provider initialization',
    () async {
      final initializer = _RecordingProviderInitializer();
      final composition = FoundationComposition(
        providerInitializer: initializer,
      );

      final Result<FoundationPreparation> prepared = await composition.prepare(
        const <String>['--clipmind-local-smoke'],
      );

      expect(prepared, isA<Failure<FoundationPreparation>>());
      expect(initializer.networkEnabled, isEmpty);
    },
  );

  test(
    'keeps a provider initialization failure as the nested provider result',
    () async {
      const providerFailure = ProviderPersistenceFailure('storage unavailable');
      const providerResult = Failure<ProviderPlatformBootstrapResult>(
        providerFailure,
      );
      final initializer = _RecordingProviderInitializer(result: providerResult);
      final composition = FoundationComposition(
        providerInitializer: initializer,
      );

      final Result<FoundationPreparation> prepared = await composition.prepare(
        const <String>[],
      );

      expect(prepared, isA<Success<FoundationPreparation>>());
      final value = (prepared as Success<FoundationPreparation>).value;
      expect(value.providerInitialization, same(providerResult));
      expect(
        value.providerInitialization,
        isA<Failure<ProviderPlatformBootstrapResult>>(),
      );
      expect(initializer.networkEnabled, <bool>[true]);
    },
  );
}

final class _RecordingProviderInitializer implements ProviderPlatformBootstrap {
  _RecordingProviderInitializer({
    Result<ProviderPlatformBootstrapResult>? result,
  }) : result =
           result ??
           Success<ProviderPlatformBootstrapResult>(
             ProviderPlatformBootstrapResult(_EmptyProviderRegistry()),
           );

  final Result<ProviderPlatformBootstrapResult> result;
  final List<bool> networkEnabled = <bool>[];

  @override
  Future<Result<ProviderPlatformBootstrapResult>> initialize({
    required bool networkEnabled,
  }) async {
    this.networkEnabled.add(networkEnabled);
    return result;
  }
}

final class _EmptyProviderRegistry implements ProviderRegistry {
  @override
  ModelProviderAdapter? adapterFor(String providerId) => null;

  @override
  ProviderDefinition? definitionFor(String providerId) => null;

  @override
  Iterable<ProviderDefinition> get definitions => const <ProviderDefinition>[];
}

Future<File> _unusedSystemTempFile(String extension) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final file = File(
      '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}'
      'clipmind-foundation-${DateTime.now().microsecondsSinceEpoch}'
      '-${_pathSequence++}$extension',
    );
    if (!await file.exists()) return file;
  }
  throw StateError('Could not allocate an unused system-temp test path.');
}

Future<void> _deleteIfPresent(File file) async {
  if (await file.exists()) await file.delete();
}
