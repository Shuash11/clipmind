import 'dart:io';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/runtime/local_smoke_coordinator.dart';
import 'package:clipmind/core/runtime/local_smoke_launch_configuration.dart';
import 'package:clipmind/core/runtime/local_smoke_reporter.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/presentation/local_smoke_screen.dart';
import 'package:clipmind/features/projects/presentation/smoke_fixture_loader.dart';
import 'package:clipmind/features/providers/data/catalog/provider_catalog.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/data/provider_registry_impl.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';
import 'package:clipmind/features/providers/presentation/widgets/provider_profile_form.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../projects/support/project_test_data.dart';

int _pathSequence = 0;

void main() {
  testWidgets(
    'renders the deterministic local project, timeline, and disabled custom provider without navigation',
    (tester) async {
      final files = _LocalSmokeFiles.create();
      addTearDown(files.delete);
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final reporter = _MemoryLocalSmokeReporter();
      final providerInitialization = _offlineProviderInitialization();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerPlatformBootstrapResultProvider.overrideWithValue(
              providerInitialization,
            ),
          ],
          child: MaterialApp(
            theme: ClipMindTheme.dark,
            home: LocalSmokeScreen(
              configuration: files.configuration,
              loader: _FakeSmokeFixtureLoader(documentWithOneClip()),
              coordinator: LocalSmokeCoordinator(reporter: reporter),
              providerInitialization: providerInitialization,
            ),
          ),
        ),
      );
      await _pumpSmokeFrames(tester);

      final timelineRegion = find.byKey(const ValueKey('timeline-data'));
      expect(timelineRegion, findsOneWidget);
      expect(
        find.descendant(
          of: timelineRegion,
          matching: find.byType(TimelineView),
        ),
        findsOneWidget,
      );
      expect(find.text('source.mp4'), findsWidgets);

      final customProviderRegion = find.byKey(
        const ValueKey('custom-provider-form'),
      );
      expect(customProviderRegion, findsOneWidget);
      final customProviderForm = find.byType(ProviderProfileForm);
      expect(customProviderForm, findsOneWidget);
      expect(
        tester
            .widget<ProviderProfileForm>(customProviderForm)
            .profile!
            .providerId,
        customOpenAiCompatibleProviderId,
      );
      expect(reporter.reports, <Map<String, Object?>>[
        <String, Object?>{
          'projectLoaded': true,
          'providersRendered': true,
          'timelineRendered': true,
          'flutterError': null,
        },
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 16));
    },
  );

  testWidgets(
    'redacts fixture-loading failures before rendering smoke regions',
    (tester) async {
      final files = _LocalSmokeFiles.create();
      addTearDown(files.delete);
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final reporter = _MemoryLocalSmokeReporter();
      final providerInitialization = _offlineProviderInitialization();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerPlatformBootstrapResultProvider.overrideWithValue(
              providerInitialization,
            ),
          ],
          child: MaterialApp(
            theme: ClipMindTheme.dark,
            home: LocalSmokeScreen(
              configuration: files.configuration,
              loader: const _FakeSmokeFixtureLoader.failure(),
              coordinator: LocalSmokeCoordinator(reporter: reporter),
              providerInitialization: providerInitialization,
            ),
          ),
        ),
      );
      await _pumpSmokeFrames(tester);

      expect(find.byKey(const ValueKey('timeline-data')), findsNothing);
      expect(find.byKey(const ValueKey('custom-provider-form')), findsNothing);
      expect(find.byType(TimelineView), findsNothing);
      expect(find.byType(ProviderProfileForm), findsNothing);
      expect(find.textContaining(files.fixture.path), findsNothing);
      expect(
        find.text('Local smoke fixture could not be loaded.'),
        findsNothing,
      );
      expect(reporter.reports, <Map<String, Object?>>[
        <String, Object?>{
          'projectLoaded': false,
          'providersRendered': false,
          'timelineRendered': false,
          'flutterError': 'flutter_error',
        },
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 16));
    },
  );
}

Success<ProviderPlatformBootstrapResult> _offlineProviderInitialization() {
  final profile = ProviderProfile(
    id: 'local-smoke-custom-profile',
    providerId: customOpenAiCompatibleProviderId,
    displayName: 'Local smoke custom provider',
    endpoint: Uri.parse('https://local-smoke.invalid/v1'),
    enabled: false,
  );
  return Success<ProviderPlatformBootstrapResult>(
    ProviderPlatformBootstrapResult(
      ProviderRegistryImpl(
        definitions: ProviderCatalog.presets,
        adapters: const <String, ModelProviderAdapter>{},
      ),
      profiles: [profile],
      activeProfileId: profile.id,
    ),
  );
}

final class _FakeSmokeFixtureLoader implements SmokeFixtureLoader {
  const _FakeSmokeFixtureLoader(this._document) : _failure = false;
  const _FakeSmokeFixtureLoader.failure() : _document = null, _failure = true;

  final ProjectDocument? _document;
  final bool _failure;

  @override
  Future<Result<ProjectDocument>> load(File fixture) async => _failure
      ? const Failure<ProjectDocument>(LocalSmokeFixtureFailure())
      : Success<ProjectDocument>(_document!);
}

final class _MemoryLocalSmokeReporter implements LocalSmokeReporter {
  final List<Map<String, Object?>> reports = <Map<String, Object?>>[];

  @override
  Future<void> write(Map<String, Object?> report) async {
    reports.add(Map<String, Object?>.from(report));
  }
}

final class _LocalSmokeFiles {
  const _LocalSmokeFiles({
    required this.fixture,
    required this.report,
    required this.configuration,
  });

  final File fixture;
  final File report;
  final LocalSmokeLaunchConfiguration configuration;

  static _LocalSmokeFiles create() {
    final fixture = _unusedSystemTempFile('.cmproj');
    final report = _unusedSystemTempFile('.json');
    fixture.writeAsStringSync('{"project":"local-smoke"}', flush: true);
    expect(report.existsSync(), isFalse);
    final parsed = LocalSmokeLaunchConfiguration.parse(<String>[
      '--clipmind-local-smoke',
      '--fixture=${fixture.path}',
      '--report=${report.path}',
    ]);
    expect(parsed, isA<Success<LocalSmokeLaunchConfiguration>>());
    return _LocalSmokeFiles(
      fixture: fixture,
      report: report,
      configuration: (parsed as Success<LocalSmokeLaunchConfiguration>).value,
    );
  }

  void delete() {
    if (fixture.existsSync()) fixture.deleteSync();
    if (report.existsSync()) report.deleteSync();
  }
}

File _unusedSystemTempFile(String extension) {
  for (var attempt = 0; attempt < 20; attempt++) {
    final file = File(
      '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}'
      'clipmind-local-smoke-${DateTime.now().microsecondsSinceEpoch}'
      '-${_pathSequence++}$extension',
    );
    if (!file.existsSync()) return file;
  }
  throw StateError('Could not allocate an unused system-temp test path.');
}

Future<void> _pumpSmokeFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
