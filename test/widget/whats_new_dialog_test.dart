import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:clipmind/core/constants/release_notes.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/repositories/settings_repository.dart';
import 'package:clipmind/presentation/project_hub/project_hub_screen.dart';
import 'package:clipmind/presentation/shared_widgets/whats_new_dialog.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

class _FakeProjectRepository extends ProjectRepository {
  _FakeProjectRepository(super.db);

  @override
  Future<void> save(Project project) async {}
}

/// Settings repository double: loads a fixed document, records saves.
class _RecordingSettingsRepository extends SettingsRepository {
  _RecordingSettingsRepository(this.initial);

  final AppSettings initial;
  AppSettings? lastSaved;

  @override
  Future<AppSettings> load() async => initial;

  @override
  Future<void> save(AppSettings settings) async {
    lastSaved = settings;
  }
}

void _mockPackageInfo(String version) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => {
      'appName': 'ClipMind',
      'packageName': 'dev.clipmind',
      'version': version,
      'buildNumber': '1',
    },
  );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      null,
    );
  });
}

/// Hub route + stub editor route (the trigger test pumps the hub only).
GoRouter _testRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ProjectHubScreen()),
      GoRoute(
        path: '/editor/:projectId',
        builder: (_, _) => const SizedBox(key: ValueKey('editor-stub')),
      ),
    ],
  );
}

void main() {
  testWidgets('WhatsNewDialog shows the bullets and Got it pops', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ClipMindTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => WhatsNewDialog.show(
                  context,
                  version: '1.22.0',
                  notes: releaseNotes['1.22.0']!,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text("What's new in v1.22.0"), findsOneWidget);
    // The user's exact release-notes format: `* ` prefixed lines.
    expect(find.text('* Working undo and redo'), findsOneWidget);
    expect(
      find.text('* Manual timeline editing: delete, copy, reorder'),
      findsOneWidget,
    );
    expect(find.text('* Cut range selection on the timeline'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text("What's new in v1.22.0"), findsNothing);
  });

  testWidgets('hub shows the whats-new dialog after an update; dismiss persists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    _mockPackageInfo('1.22.0');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = _RecordingSettingsRepository(
      const AppSettings(lastSeenVersion: '1.21.0'),
    );
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
        projectRepositoryProvider.overrideWithValue(_FakeProjectRepository(db)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ClipMindTheme.dark,
          routerConfig: _testRouter(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("What's new in v1.22.0"), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text("What's new in v1.22.0"), findsNothing);
    expect(repo.lastSaved?.lastSeenVersion, equals('1.22.0'));
  });

  testWidgets('first run persists lastSeenVersion silently, no dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    _mockPackageInfo('1.22.0');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = _RecordingSettingsRepository(const AppSettings());
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
        projectRepositoryProvider.overrideWithValue(_FakeProjectRepository(db)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ClipMindTheme.dark,
          routerConfig: _testRouter(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("What's new in v1.22.0"), findsNothing);
    // The first run recorded the version silently.
    expect(repo.lastSaved?.lastSeenVersion, equals('1.22.0'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no dialog when the current version has no notes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    _mockPackageInfo('9.9.9');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = _RecordingSettingsRepository(
      const AppSettings(lastSeenVersion: '1.21.0'),
    );
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
        projectRepositoryProvider.overrideWithValue(_FakeProjectRepository(db)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ClipMindTheme.dark,
          routerConfig: _testRouter(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("What's new in v9.9.9"), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
