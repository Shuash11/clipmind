import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/presentation/project_hub/project_hub_screen.dart';
import 'package:clipmind/presentation/project_hub/widgets/blank_project_card.dart';
import 'package:clipmind/presentation/project_hub/widgets/recent_project_card.dart';
import 'package:clipmind/presentation/shared_widgets/dashed_border.dart';
import 'package:clipmind/state/project_providers.dart';

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

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('hub renders top bar pills, hero copy, and dashed dropzone', (
    tester,
  ) async {
    final repo = _FakeProjectRepository(
      db: db,
      recent: [_project(durationMs: 154000)],
    );
    final container = ProviderContainer(
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

  testWidgets('blank card renders first in the recent row', (tester) async {
    final repo = _FakeProjectRepository(
      db: db,
      recent: [_project(durationMs: 154000)],
    );
    final container = ProviderContainer(
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
    final container = ProviderContainer(
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
    expect(container.read(projectProvider).valueOrNull?.id, 'blank-1');
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
    final container = ProviderContainer(
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
}
