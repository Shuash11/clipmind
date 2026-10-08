import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/updates/github_release_checker.dart';
import 'package:clipmind/data/services/updates/release_info.dart';
import 'package:clipmind/data/services/import/url_import_service.dart';
import 'package:clipmind/data/services/import/youtube_import_service.dart';
import 'package:clipmind/presentation/project_hub/project_hub_screen.dart';
import 'package:clipmind/presentation/project_hub/widgets/blank_project_card.dart';
import 'package:clipmind/presentation/project_hub/widgets/recent_project_card.dart';
import 'package:clipmind/presentation/project_hub/widgets/yt_dlp_guidance_dialog.dart';
import 'package:clipmind/presentation/shared_widgets/dashed_border.dart';
import 'package:clipmind/state/ffmpeg_providers.dart';
import 'package:clipmind/state/import_providers.dart';
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
  List<List<String>> createdSourceMediaPaths = [];

  @override
  Future<Project> createNew(
    String name, {
    List<String> sourceMediaPaths = const [],
    int durationMs = 0,
    String? thumbnailPath,
  }) async {
    created++;
    createdNames.add(name);
    createdSourceMediaPaths.add(sourceMediaPaths);
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

/// Persistence-failure fake: createNew throws the repository's loud
/// [PersistenceFailure], mirroring a `.cmproj` write that cannot land.
class _FailingSaveProjectRepository extends _FakeProjectRepository {
  _FailingSaveProjectRepository({required super.db, super.recent});

  @override
  Future<Project> createNew(
    String name, {
    List<String> sourceMediaPaths = const [],
    int durationMs = 0,
    String? thumbnailPath,
  }) async {
    throw const PersistenceFailure('The project could not be saved to disk.');
  }
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

/// Fake YouTube service: scripted availability, and an import that stays
/// pending until the test emits progress/errors or cancels. The streams are
/// broadcast controllers created up front, mirroring the real services'
/// "controllers exist before a listener subscribes" contract.
class _FakeYouTubeImportService extends YouTubeImportService {
  _FakeYouTubeImportService({required this.availability, this.availabilityGate});

  final YtDlpAvailability availability;
  final Completer<YtDlpAvailability>? availabilityGate;
  final _progress = StreamController<double>.broadcast();
  final _errors = StreamController<String>.broadcast();

  int checkCalls = 0;
  int importCalls = 0;
  int cancelCalls = 0;
  String? lastUrl;
  String? lastOutputDir;
  Completer<String?>? _pending;

  @override
  Stream<double> get progress => _progress.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Future<YtDlpAvailability> checkAvailability() {
    checkCalls++;
    final gate = availabilityGate;
    if (gate != null) return gate.future;
    return Future.value(availability);
  }

  @override
  Future<String?> import(String url, String outputDir) {
    importCalls++;
    lastUrl = url;
    lastOutputDir = outputDir;
    _pending = Completer<String?>();
    return _pending!.future;
  }

  @override
  void cancel() {
    cancelCalls++;
    _pending?.complete(null);
    _pending = null;
  }

  void emitProgress(double value) => _progress.add(value);
}

/// Fake direct-URL service: pending import plus a cancel that mimics the
/// real service by also emitting its own "Download cancelled" error.
class _FakeUrlImportService extends UrlImportService {
  final _progress = StreamController<double>.broadcast();
  final _errors = StreamController<String>.broadcast();

  int importCalls = 0;
  int cancelCalls = 0;
  String? lastUrl;
  String? lastTargetDir;
  Completer<String?>? _pending;

  @override
  Stream<double> get progress => _progress.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Future<String?> import(String fileUrl, String targetDir) {
    importCalls++;
    lastUrl = fileUrl;
    lastTargetDir = targetDir;
    _pending = Completer<String?>();
    return _pending!.future;
  }

  @override
  void cancel() {
    cancelCalls++;
    _errors.add('Download cancelled');
    _pending?.complete(null);
    _pending = null;
  }

  /// Completes the pending import with [path], as a finished download does.
  void completeImport(String? path) {
    _pending?.complete(path);
    _pending = null;
  }

  /// Emits [message] on the errors stream and completes as a failed import,
  /// mirroring the real service's rejected-payload path.
  void failImport(String message) {
    _errors.add(message);
    _pending?.complete(null);
    _pending = null;
  }

  void emitProgress(double value) => _progress.add(value);
}

/// Fake ffprobe: [extractMetadata] waits on [metadataGate] so the hub's
/// open step (ffprobe + thumbnail) can be observed mid-flight; the
/// thumbnail resolves immediately to no path.
class _FakeFfprobeService extends FfprobeService {
  _FakeFfprobeService({required this.metadataGate});

  final Completer<VideoMetadata?> metadataGate;

  @override
  Future<VideoMetadata?> extractMetadata(String filePath) =>
      metadataGate.future;

  @override
  Future<String?> generateThumbnail(
    String filePath, {
    int atMs = 0,
    String? outputPath,
  }) async => null;
}

List<Override> _importServiceOverrides({
  _FakeYouTubeImportService? youtube,
  _FakeUrlImportService? url,
}) {
  return [
    if (youtube != null)
      youtubeImportServiceFactoryProvider.overrideWithValue(() => youtube),
    if (url != null)
      urlImportServiceFactoryProvider.overrideWithValue(() => url),
  ];
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

  testWidgets('blank card shows save-failure copy when persistence fails', (
    tester,
  ) async {
    final repo = _FailingSaveProjectRepository(db: db, recent: [_project()]);
    final container = ProviderContainer.test(
      overrides: [projectRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await _pumpHub(tester, container);
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey('blank-project-card')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('blank-project-card')));
    await tester.pump();
    await tester.pump();

    // Honest copy: the project could not be written to disk, not a generic
    // "could not create" or import failure.
    expect(find.text('Could not save the project to disk.'), findsOneWidget);
    expect(find.text('Could not create the project.'), findsNothing);
    // No phantom navigation: the failure keeps the user on the hub.
    expect(find.byKey(const ValueKey('editor-stub')), findsNothing);
    expect(tester.takeException(), isNull);
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

  group('URL import preflight, progress, and cancel', () {
    Future<ProviderContainer> pumpImportHub(
      WidgetTester tester, {
      _FakeYouTubeImportService? youtube,
      _FakeUrlImportService? url,
      FfprobeService? ffprobe,
      _FakeProjectRepository? repo,
    }) async {
      final repository = repo ?? _FakeProjectRepository(db: db);
      final container = ProviderContainer.test(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          if (ffprobe != null)
            ffprobeServiceProvider.overrideWithValue(ffprobe),
          ..._importServiceOverrides(youtube: youtube, url: url),
        ],
      );
      addTearDown(container.dispose);
      await _pumpHub(tester, container);
      await tester.pump();
      return container;
    }

    testWidgets(
      'YouTube preflight starts the import, streams determinate progress, '
      'and cancel resets to idle with one notice',
      (tester) async {
        final youtube = _FakeYouTubeImportService(
          availability: const YtDlpAvailability.available('2026.05.01'),
        );
        _mockPathProvider(importTempDir.path);
        await pumpImportHub(tester, youtube: youtube);

        await tester.enterText(
          find.byType(TextField),
          'https://www.youtube.com/watch?v=abc123',
        );
        await tester.pump();

        // The preflight + spawn touch real dart:io (imports dir), so drive
        // them in the real async zone.
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Import'));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();

        expect(youtube.checkCalls, 1);
        expect(youtube.importCalls, 1);
        expect(youtube.lastUrl, 'https://www.youtube.com/watch?v=abc123');
        expect(youtube.lastOutputDir, endsWith('imports'));

        // No stream value yet: indeterminate track, label without percent.
        final pending = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('url-import-progress')),
        );
        expect(pending.value, isNull);
        expect(find.text('Downloading…'), findsOneWidget);

        youtube.emitProgress(0.25);
        await tester.pump();
        final quarter = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('url-import-progress')),
        );
        expect(quarter.value, closeTo(0.25, 0.0001));
        expect(find.text('Downloading… 25%'), findsOneWidget);

        final semanticsHandle = tester.ensureSemantics();
        final progressSemantics = tester.getSemantics(
          find.byKey(const ValueKey('url-import-progress')),
        );
        expect(progressSemantics.label, 'Download progress');
        expect(progressSemantics.value, '25%');
        semanticsHandle.dispose();

        youtube.emitProgress(0.75);
        await tester.pump();
        final threeQuarters = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('url-import-progress')),
        );
        expect(threeQuarters.value, closeTo(0.75, 0.0001));
        expect(find.text('Downloading… 75%'), findsOneWidget);

        // Cancel: the fake's cancel() runs, the bar returns to idle, and
        // exactly one notice is shown.
        expect(find.byTooltip('Cancel download'), findsOneWidget);
        await tester.tap(find.byTooltip('Cancel download'));
        await tester.pump();

        expect(youtube.cancelCalls, 1);
        expect(find.text('Download cancelled'), findsOneWidget);
        expect(find.byKey(const ValueKey('url-import-progress')), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Import'), findsOneWidget);
        expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

        // No duplicate notice arrives on later frames. Visibility alone
        // cannot prove nothing is queued: after the first notice's 4s
        // duration elapses and it leaves, nothing may remain.
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Download cancelled'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text('Download cancelled'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('unavailable yt-dlp shows guidance and never spawns', (
      tester,
    ) async {
      final youtube = _FakeYouTubeImportService(
        availability: const YtDlpAvailability.unavailable(
          YouTubeImportService.missingBinaryMessage,
        ),
      );
      await pumpImportHub(tester, youtube: youtube);
      await tester.enterText(find.byType(TextField), 'https://youtu.be/abc');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      expect(youtube.checkCalls, 1);
      expect(youtube.importCalls, 0);
      expect(find.text('yt-dlp is required for YouTube links'), findsOneWidget);
      expect(find.textContaining('yt-dlp_macos'), findsOneWidget);
      expect(find.textContaining('deno'), findsOneWidget);
      expect(find.textContaining('winget'), findsNothing);
      // Behind the dialog the bar is back to idle.
      expect(find.widgetWithText(FilledButton, 'Import'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('yt-dlp is required for YouTube links'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('guidance dialog opens the official yt-dlp releases page', (
      tester,
    ) async {
      final launchedUrls = <String>[];
      final useWebViewFlags = <bool>[];
      _mockUrlLauncher(
        result: true,
        launchedUrls: launchedUrls,
        useWebViewFlags: useWebViewFlags,
      );

      final youtube = _FakeYouTubeImportService(
        availability: const YtDlpAvailability.unavailable(
          YouTubeImportService.missingBinaryMessage,
        ),
      );
      await pumpImportHub(tester, youtube: youtube);
      await tester.enterText(find.byType(TextField), 'https://youtu.be/abc');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Open download page'),
      );
      await tester.pumpAndSettle();

      expect(launchedUrls, [YtDlpGuidanceDialog.downloadPageUrl]);
      // LaunchMode.externalApplication maps to useWebView: false.
      expect(useWebViewFlags, [false]);
      expect(find.text('yt-dlp is required for YouTube links'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('guidance launch failure surfaces the fallback notice', (
      tester,
    ) async {
      _mockUrlLauncher(result: false);

      final youtube = _FakeYouTubeImportService(
        availability: const YtDlpAvailability.unavailable(
          YouTubeImportService.missingBinaryMessage,
        ),
      );
      await pumpImportHub(tester, youtube: youtube);
      await tester.enterText(find.byType(TextField), 'https://youtu.be/abc');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Open download page'),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not open the download page'),
        findsOneWidget,
      );
      expect(find.text('yt-dlp is required for YouTube links'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('host-based routing picks YouTube for youtube hosts only', (
      tester,
    ) async {
      const youtubeUrls = [
        'https://youtube.com/watch?v=abc123',
        'https://www.youtube.com/watch?v=abc123',
        'https://music.youtube.com/watch?v=abc123',
        'https://youtu.be/abc123',
        'https://www.youtu.be/abc123',
      ];
      const directUrls = [
        // Regression: the old substring check routed these to yt-dlp.
        'https://notyoutube.com/watch?v=abc123',
        'https://youtube.com.evil.example/video.mp4',
      ];

      for (final url in youtubeUrls) {
        final youtube = _FakeYouTubeImportService(
          availability: const YtDlpAvailability.available('2026.05.01'),
        );
        final urlFake = _FakeUrlImportService();
        _mockPathProvider(importTempDir.path);
        await pumpImportHub(tester, youtube: youtube, url: urlFake);
        await tester.enterText(find.byType(TextField), url);
        await tester.pump();

        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Import'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();

        expect(youtube.importCalls, 1, reason: url);
        expect(urlFake.importCalls, 0, reason: url);
      }

      for (final url in directUrls) {
        final youtube = _FakeYouTubeImportService(
          availability: const YtDlpAvailability.available('2026.05.01'),
        );
        final urlFake = _FakeUrlImportService();
        _mockPathProvider(importTempDir.path);
        await pumpImportHub(tester, youtube: youtube, url: urlFake);
        await tester.enterText(find.byType(TextField), url);
        await tester.pump();

        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Import'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();

        expect(youtube.importCalls, 0, reason: url);
        expect(urlFake.importCalls, 1, reason: url);
        expect(
          urlFake.lastTargetDir,
          equals('${importTempDir.path}/imports'),
          reason: url,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'direct-URL cancel shows exactly one notice despite the service error',
      (tester) async {
        final urlFake = _FakeUrlImportService();
        _mockPathProvider(importTempDir.path);
        await pumpImportHub(tester, url: urlFake);

        await tester.enterText(
          find.byType(TextField),
          'https://cdn.example.com/clip.mp4',
        );
        await tester.pump();

        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Import'));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        expect(urlFake.importCalls, 1);

        urlFake.emitProgress(0.5);
        await tester.pump();
        expect(find.text('Downloading… 50%'), findsOneWidget);

        await tester.tap(find.byTooltip('Cancel download'));
        await tester.pump();

        expect(urlFake.cancelCalls, 1);
        // The fake emitted its own "Download cancelled" on the errors
        // stream; the stale generation drops it — one notice, not two.
        expect(find.text('Download cancelled'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Download cancelled'), findsOneWidget);
        // ScaffoldMessenger queues SnackBars, so visibility cannot prove
        // there is no duplicate: after the 4s duration elapses and the
        // notice leaves, nothing may remain.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text('Download cancelled'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Import'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'cancel affordance disappears once the download resolves, before '
      'the project opens',
      (tester) async {
        final metadataGate = Completer<VideoMetadata?>();
        final urlFake = _FakeUrlImportService();
        _mockPathProvider(importTempDir.path);
        final container = await pumpImportHub(
          tester,
          url: urlFake,
          ffprobe: _FakeFfprobeService(metadataGate: metadataGate),
        );

        await tester.enterText(
          find.byType(TextField),
          'https://cdn.example.com/clip.mp4',
        );
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Import'));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        expect(urlFake.importCalls, 1);
        expect(find.byTooltip('Cancel download'), findsOneWidget);

        // The download resolves while the open step (ffprobe + thumbnail)
        // is still pending. Real async zone: the import future's
        // continuation was registered there by the runAsync tap.
        await tester.runAsync(() async {
          urlFake.completeImport(
            '${importTempDir.path}/imports/'
            '0f8fad5b-d9cb-469f-a165-70867728950e/clip.mp4',
          );
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Nothing left to cancel: the affordance is gone before the open
        // step, so no "Download cancelled" can appear while the project is
        // about to open. The bar itself stays disabled (_isImporting).
        expect(find.byTooltip('Cancel download'), findsNothing);
        expect(find.byKey(const ValueKey('url-import-progress')), findsNothing);
        expect(find.text('Download cancelled'), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(find.widgetWithText(FilledButton, 'Importing'), findsOneWidget);

        // Completing the probe lets the project-open path proceed.
        await tester.runAsync(() async {
          metadataGate.complete(null);
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        await tester.pump();
        expect(container.read(projectProvider).value?.name, 'clip.mp4');
        expect(find.byKey(const ValueKey('editor-stub')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'imported path basename becomes the created project name',
      (tester) async {
        final repo = _FakeProjectRepository(db: db);
        final urlFake = _FakeUrlImportService();
        final metadataGate = Completer<VideoMetadata?>();
        _mockPathProvider(importTempDir.path);
        final container = await pumpImportHub(
          tester,
          url: urlFake,
          repo: repo,
          ffprobe: _FakeFfprobeService(metadataGate: metadataGate),
        );

        await tester.enterText(
          find.byType(TextField),
          'https://cdn.example.com/clip.mp4',
        );
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Import'));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        expect(urlFake.importCalls, 1);

        // Production shape: {imports}/<uuid>/<real name>.
        final downloaded = '${importTempDir.path}/imports/'
            '0f8fad5b-d9cb-469f-a165-70867728950e/café clip.mp4';
        await tester.runAsync(() async {
          urlFake.completeImport(downloaded);
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });

        // Completing the probe lets the project-open path proceed.
        await tester.runAsync(() async {
          metadataGate.complete(null);
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        await tester.pump();

        expect(repo.createdNames, ['café clip.mp4']);
        expect(repo.createdSourceMediaPaths, [
          [downloaded],
        ]);
        expect(container.read(projectProvider).value?.name, 'café clip.mp4');
        expect(find.byKey(const ValueKey('editor-stub')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a web-page link surfaces the typed not-a-video message',
      (tester) async {
        final urlFake = _FakeUrlImportService();
        _mockPathProvider(importTempDir.path);
        await pumpImportHub(tester, url: urlFake);

        await tester.enterText(
          find.byType(TextField),
          'https://example.com/page',
        );
        await tester.pump();
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Import'));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();
        expect(urlFake.importCalls, 1);

        await tester.runAsync(() async {
          urlFake.failImport(UrlImportService.notVideoMessage);
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text(UrlImportService.notVideoMessage), findsOneWidget);
        // The generic fallback must not fire alongside the typed message,
        // and the failed import must not open a project.
        expect(
          find.text('Import failed. Check the URL and try again.'),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('editor-stub')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('YouTube preflight exposes a compact checking state', (
      tester,
    ) async {
      final gate = Completer<YtDlpAvailability>();
      final youtube = _FakeYouTubeImportService(
        availability: const YtDlpAvailability.available('2026.05.01'),
        availabilityGate: gate,
      );
      await pumpImportHub(tester, youtube: youtube);
      await tester.enterText(find.byType(TextField), 'https://youtu.be/abc');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pump();

      expect(youtube.checkCalls, 1);
      expect(youtube.importCalls, 0);
      expect(find.text('Checking'), findsOneWidget);
      expect(find.byTooltip('Cancel download'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Checking'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// Stubs the url_launcher method channel: records every launched URL (and
/// the useWebView option) and answers [result], so the guidance dialog's
/// browser launch is observable and its failure path controllable.
void _mockUrlLauncher({
  required bool result,
  List<String>? launchedUrls,
  List<bool>? useWebViewFlags,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (call) async {
      if (call.method == 'launch') {
        final args = call.arguments as Map<Object?, Object?>;
        launchedUrls?.add(args['url'] as String);
        useWebViewFlags?.add(args['useWebView'] as bool);
        return result;
      }
      return null;
    },
  );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      null,
    );
  });
}
