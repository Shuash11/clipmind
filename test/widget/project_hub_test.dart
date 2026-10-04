import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/services/updates/github_release_checker.dart';
import 'package:clipmind/data/services/updates/release_info.dart';
import 'package:clipmind/data/services/import/url_import_service.dart';
import 'package:clipmind/presentation/project_hub/project_hub_screen.dart';
import 'package:clipmind/presentation/project_hub/widgets/blank_project_card.dart';
import 'package:clipmind/presentation/project_hub/widgets/recent_project_card.dart';
import 'package:clipmind/presentation/shared_widgets/dashed_border.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/update_providers.dart';

/// Fake repository: no file IO (path_provider hangs in this sandbox);
/// returns a fixed recent list and records createNew calls. The memory DB
/// is shared from the test's setUp/tearDown so it closes cleanly.
class _FakeProjectRepository extends ProjectRepository {
  _FakeProjectRepository({required AppDatabase db, this.recent = const []})
      : super(db);

  final List<Project> recent;
  int created = 0;
  List<String> createdNames = [];

  @override
  Future<Project> createNew(
    String name, {
    List<String> sourceMediaPaths = const [],
    int durationMs = 0,
    String? thumbnailPath,
  }) async {
    created++;
    createdNames.add(name);
    return Project(
      id: 'blank-$created',
      name: name,
      createdAt: DateTime(2026, 9, 26, 21),
      updatedAt: DateTime(2026, 9, 26, 21),
    );
  }

  @override
  Future<void> save(Project project) async {}

  @override
  Future<List<Project>> listRecent() async => recent;
}

Project _project({int durationMs = 0}) {
  return Project(
    id: 'p1',
    name: 'Test project',
    createdAt: DateTime(2026, 9, 26, 9),
    updatedAt: DateTime(2026, 9, 26, 9),
    durationMs: durationMs,
  );
}

/// Hub route + stub editor route: navigation is observable without pumping
/// the real editor (media_kit does not settle in this sandbox).
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

/// Desktop viewport by default: the hub's design (maxWidth 1180 container,
/// top-bar pills) targets a desktop window; the 800x600 default is too
/// narrow. [viewport] overrides for narrow-window tests.
void _useDesktopViewport(
  WidgetTester tester, [
  Size viewport = const Size(1280, 800),
]) {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpHub(
  WidgetTester tester,
  ProviderContainer container, {
  Size viewport = const Size(1280, 800),
}) {
  _useDesktopViewport(tester, viewport);
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _testRouter()),
    ),
  );
}

/// Package-info stub (the whats_new_dialog_test pattern): [version] is
/// what _initUpdateCheck reports as the running version.
void _mockPackageInfo(String version) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => {
      'appName': 'ClipMind',
      'packageName': 'dev.clipmind',
      'version': version,
      'buildNumber': '2',
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

/// path_provider stub: getApplicationSupportDirectory returns
/// [appSupportPath] so platform-channel-backed flows never hang or touch
/// the real file system.
void _mockPathProvider(String appSupportPath) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return appSupportPath;
      }
      return null;
    },
  );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });
}

/// Deterministic update check: checkForUpdate resolves to no release.
class _FailingChecker extends GithubReleaseChecker {
  @override
  Future<ReleaseInfo?> checkForUpdate() async => null;
}

void main() {
  late AppDatabase db;
  late Directory importTempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Real async zone: dart:io must not run inside testWidgets' FakeAsync.
    importTempDir = await Directory.systemTemp.createTemp('hub_drive_test_');
  });

  tearDown(() async {
    await db.close();
    try {
      await importTempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('hub renders top bar pills, hero copy, and dashed dropzone', (
    tester,
  ) async {
    final repo = _FakeProjectRepository(
      db: db,
      recent: [_project(durationMs: 154000)],
    );
    final container = ProviderContainer.test(
      overrides: [projectRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpHub(tester, container);
    await tester.pump();

    // Top bar: pills + retained settings action.
    expect(find.byKey(const ValueKey('new-project-pill')), findsOneWidget);
    expect(find.byKey(const ValueKey('project-hub-settings')), findsOneWidget);
    expect(find.text('AI model'), findsOneWidget);
    expect(find.text('+ New project'), findsOneWidget);
    // Two-tone wordmark still resolves to its plain text.
    expect(find.text('ClipMind'), findsOneWidget);
    // Centered hero copy.
    expect(find.text('What are we editing today?'), findsOneWidget);
    expect(
      find.textContaining('your AI assistant is ready to help'),
      findsOneWidget,
    );
    // Uppercase section headers + import card copy.
    expect(find.text('IMPORT FROM'), findsOneWidget);
    expect(find.text('RECENT PROJECTS'), findsOneWidget);
    expect(find.text('Paste a URI'), findsOneWidget);
    // Dashed dropzone with copy and the full format list.
    expect(find.text('Drag and drop your video here'), findsOneWidget);
    expect(find.text('or click to browse your files'), findsOneWidget);
    expect(find.text('MP4 · MOV · AVI · WEBM · MKV'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DashedRRectPainter,
      ),
      findsWidgets,
    );
    // Recent row: blank card first, duration badge on the thumbnail.
    expect(find.byType(BlankProjectCard), findsOneWidget);
    expect(find.byKey(const ValueKey('blank-project-card')), findsOneWidget);
    expect(find.text('2:34'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top bar logo tile renders the bundled ClipMind asset', (
    tester,
  ) async {
    final repo = _FakeProjectRepository(db: db);
    final container = ProviderContainer.test(
      overrides: [projectRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpHub(tester, container);
    await tester.pump();

    final image = tester.widget<Image>(find.byKey(const ValueKey('hub-logo')));
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      'assets/icons/clipmind_logo.png',
    );
    // The tile keeps its rounded-square + border design; the 14% accent
    // fill is dropped because the logo PNG carries its own violet
    // background. The border rides in foregroundDecoration (painted over
    // the full-bleed image).
    final tile = tester.widget<Container>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('hub-logo')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  (w.decoration as BoxDecoration?)?.borderRadius != null,
            ),
          )
          .first,
    );
    final decoration = tile.decoration! as BoxDecoration;
    final foreground = tile.foregroundDecoration! as BoxDecoration;
    expect(decoration.color, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(10));
    expect(foreground.border, isNotNull);
    // Let the real asset bundle decode; a missing/broken asset throws here.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank card renders first in the recent row', (tester) async {
    final repo = _FakeProjectRepository(
      db: db,
      recent: [_project(durationMs: 154000)],
    );
    final container = ProviderContainer.test(
      overrides: [projectRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpHub(tester, container);
    await tester.pump();

    final blankRect = tester.getRect(
      find.byKey(const ValueKey('blank-project-card')),
    );
    final cardRect = tester.getRect(find.byType(RecentProjectCard));
    expect(blankRect.left, lessThan(cardRect.left));
  });

  testWidgets('blank card creates and opens an empty project', (tester) async {
    final repo = _FakeProjectRepository(db: db, recent: [_project()]);
    final container = ProviderContainer.test(
      overrides: [projectRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpHub(tester, container);
    await tester.pump();

    // The blank card sits below the fold at the desktop viewport.
    await tester.ensureVisible(find.byKey(const ValueKey('blank-project-card')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('blank-project-card')));
    await tester.pump();
    await tester.pump();

    expect(repo.created, equals(1));
    expect(repo.createdNames, equals(['Blank project']));
    // Navigation reached the editor route with the new project id.
    expect(find.byKey(const ValueKey('editor-stub')), findsOneWidget);
    expect(container.read(projectProvider).value?.id, 'blank-1');
  });

  testWidgets('duration badge shows M:SS and H:MM:SS, hidden when pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 214,
              child: RecentProjectCard(
                project: _project(durationMs: 154000),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('2:34'), findsOneWidget);
    // The old duration text row is gone.
    expect(find.textContaining('2m 34s'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 214,
              child: RecentProjectCard(
                project: _project(durationMs: 3754000),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1:02:34'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 214,
              child: RecentProjectCard(project: _project()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // No badge while the duration is pending.
    expect(find.textContaining(':'), findsNothing);
  });

  testWidgets('dashed border paints without exceptions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DashedBorder(
              color: ClipMindColors.accentPrimary,
              radius: 16,
              child: Container(
                width: 200,
                height: 120,
                alignment: Alignment.center,
                child: const Text('content'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('content'), findsOneWidget);
  });

  test('dashed painter repaints on style change only', () {
    final white = DashedRRectPainter(color: ClipMindColors.accentPrimary);
    expect(
      white.shouldRepaint(
        DashedRRectPainter(color: ClipMindColors.borderColor),
      ),
      isTrue,
    );
    expect(
      white.shouldRepaint(
        DashedRRectPainter(color: ClipMindColors.accentPrimary),
      ),
      isFalse,
    );
    expect(
      white.shouldRepaint(
        DashedRRectPainter(color: ClipMindColors.accentPrimary, radius: 14),
      ),
      isTrue,
    );
  });

  testWidgets('top bar pills do not overflow on narrow windows', (
    tester,
  ) async {
    final repo = _FakeProjectRepository(db: db);
    final container = ProviderContainer.test(
      overrides: [projectRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    // Narrower than the 800px default where the bar previously overflowed.
    await _pumpHub(tester, container, viewport: const Size(720, 800));
    await tester.pump();

    expect(find.byKey(const ValueKey('new-project-pill')), findsOneWidget);
    expect(find.byKey(const ValueKey('project-hub-settings')), findsOneWidget);
    expect(find.text('AI model'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('import cards show YouTube and URI only, no Drive card', (
    tester,
  ) async {
    final repo = _FakeProjectRepository(db: db);
    final container = ProviderContainer.test(
      overrides: [projectRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpHub(tester, container);
    await tester.pump();

    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Paste a URI'), findsOneWidget);
    expect(find.text('Google Drive'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drive share link shows the guidance snackbar', (tester) async {
    final repo = _FakeProjectRepository(db: db);
    final container = ProviderContainer.test(
      overrides: [projectRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    _mockPathProvider(importTempDir.path);

    await _pumpHub(tester, container);
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      'https://drive.google.com/file/d/ABCDefghij1234567890abc/view',
    );
    await tester.pump();
    // The whole submit runs in the real async zone: the import path awaits
    // real dart:io work (_getImportDir), which never resolves under
    // testWidgets' FakeAsync.
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    // Pumps render the resulting snackbar frame.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find
          .text(UrlImportService.driveLinkMessage)
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(find.text(UrlImportService.driveLinkMessage), findsOneWidget);
    // The generic fallback must not fire alongside the guidance.
    expect(
      find.text('Import failed. Check the URL and try again.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hub shows the failed-update snackbar on startup', (
    tester,
  ) async {
    _mockPackageInfo('1.36.2');
    _mockPathProvider(importTempDir.path);
    final repo = _FakeProjectRepository(db: db, recent: [_project()]);
    final container = ProviderContainer.test(
      overrides: [
        projectRepositoryProvider.overrideWithValue(repo),
        // Deterministic update check: a failing checker can never inject
        // an update dialog or snackbar into this startup test.
        githubReleaseCheckerProvider.overrideWithValue(_FailingChecker()),
      ],
    );
    addTearDown(container.dispose);

    // The helper scripts wrote a failed result before relaunching; the
    // hub's startup consume must surface the reason. Real async zone:
    // dart:io must not run inside testWidgets' FakeAsync.
    await tester.runAsync(() async {
      final updatesDir = Directory('${importTempDir.path}/updates');
      await updatesDir.create(recursive: true);
      await File('${updatesDir.path}/update-result.json').writeAsString(
        '{"status":"failed","reason":"Installer exited with code 5",'
        '"expectedVersion":"1.36.3","finishedAt":"2026-10-04T16:00:00.000Z"}',
      );
    });

    await _pumpHub(tester, container);
    // Flushes the stubbed channel calls + startup consume, then renders
    // the snackbar frame.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Installer exited with code 5').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Installer exited with code 5'), findsOneWidget);
    // The result file was consumed after read.
    expect(
      File(
        '${importTempDir.path.replaceAll('\\', '/')}/updates/update-result.json',
      ).existsSync(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
