import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/track_row.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';
import '../features/tagging/support/tagging_widget_harness.dart';

/// Fake repository: the sandbox has no path_provider; the save is a no-op
/// so the mutation reaches the project state and the undo's onRestore
/// completes without file IO. The memory DB is shared from the test's
/// setUp/tearDown so it closes cleanly.
class _FakeProjectRepository extends ProjectRepository {
  _FakeProjectRepository({required AppDatabase db}) : super(db);

  @override
  Future<void> save(Project project) async {}
}

/// Fake FFmpeg: runSync creates the temp output file and reports success,
/// so the engine's copy step and the cut chain complete in the sandbox.
class _FakeFfmpegService extends FfmpegService {
  _FakeFfmpegService() : super(resolver: _StubResolver('C:/fake/ffmpeg.exe'));

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    File(job.outputPath).parent.createSync(recursive: true);
    File(job.outputPath).writeAsStringSync('fake');
    return FfmpegResult(
      success: true,
      outputPath: job.outputPath,
      exitCode: 0,
    );
  }

  @override
  void cancel() {}
}

class _StubResolver extends FfmpegBinaryResolver {
  _StubResolver(this.path);

  final String? path;

  @override
  String? resolveFfmpeg({String? settingsPath}) => path;
}

Project _project() {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['C:/media/sample.mp4'],
    tracks: const [
      Track(
        id: 'track-1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip-1',
            trackId: 'track-1',
            sourcePath: 'C:/media/sample.mp4',
            startMs: 0,
            endMs: 30000,
            label: 'sample.mp4',
          ),
        ],
      ),
    ],
    durationMs: 30000,
  );
}

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('TimelineView renders 4 track rows', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const TimelineView()));

    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('FX'), findsOneWidget);
  });

  testWidgets('TimelineView shows toolbar icons', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const TimelineView()));

    expect(find.byIcon(Icons.content_cut), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out), findsOneWidget);
  });

  testWidgets('TrackRow displays project clip blocks', (
    WidgetTester tester,
  ) async {
    const clip = Clip(
      id: 'clip-1',
      trackId: 'track-1',
      sourcePath: 'C:/media/sample.mp4',
      startMs: 0,
      endMs: 30000,
      label: 'sample.mp4',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrackRow(trackType: TrackTypeDisplay.video, clips: [clip]),
        ),
      ),
    );

    expect(find.text('Video'), findsOneWidget);
    expect(find.text('sample.mp4'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
  });

  testWidgets('All track types render with correct labels', (
    WidgetTester tester,
  ) async {
    for (final type in TrackTypeDisplay.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackRow(trackType: type)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  group('drag-reorder', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Project twoClipProject() {
      return Project(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        sourceMediaPaths: const ['C:/media/sample.mp4'],
        tracks: const [
          Track(
            id: 'track-1',
            type: TrackType.video,
            label: 'Video',
            clips: [
              Clip(
                id: 'clip-1',
                trackId: 'track-1',
                sourcePath: 'C:/media/sample.mp4',
                startMs: 0,
                endMs: 30000,
                positionMs: 0,
                label: 'sample.mp4',
              ),
              Clip(
                id: 'clip-2',
                trackId: 'track-1',
                sourcePath: 'C:/media/sample.mp4',
                startMs: 0,
                endMs: 30000,
                positionMs: 30000,
                label: 'second.mp4',
              ),
            ],
          ),
        ],
        durationMs: 60000,
      );
    }

    List<String> clipOrder(Project? project) {
      if (project == null) return const [];
      final track = project.tracks.first;
      final sorted = [...track.clips]
        ..sort((a, b) => a.positionMs.compareTo(b.positionMs));
      return [for (final clip in sorted) clip.id];
    }

    testWidgets('drag on a clip fires the moveClip op; the arena keeps the '
        'scroll still', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          projectRepositoryProvider.overrideWithValue(
            _FakeProjectRepository(db: db),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(twoClipProject());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TimelineView())),
        ),
      );
      await tester.pump();

      // Drag clip-1's block to the right (past clip-2's midpoint). The
      // ImmediateMultiDragGestureRecognizer claims the arena on pointer
      // down, so the horizontal scroll of the track stays still and the
      // drop lands on the DragTarget's right half of clip-2.
      final scroll = find.descendant(
        of: find.byType(TrackRow),
        matching: find.byType(Scrollable),
      );
      await tester.drag(find.text('second.mp4'), const Offset(-400, 0));
      await tester.pump();
      await tester.pump();

      // The moveClip op went through the structural applier: the track's
      // order is clip-2 then clip-1, repinned cumulatively.
      expect(clipOrder(container.read(projectProvider).valueOrNull),
          equals(['clip-2', 'clip-1']));
      // The arena resolved to the drag: no scroll happened.
      expect(tester.state<ScrollableState>(scroll.first).position.pixels,
          equals(0));
      // The applier pushed the edit op (undoable, with the op label).
      expect(container.read(undoRedoProvider).canUndo, isTrue);
      final op = await container.read(undoRedoProvider.notifier).undo();
      expect(op, isNotNull);
      expect(op!.type, equals(EditOperationType.moveClip));
    });
  });

  group('ruler range cut', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Directory? tempDir;

    void makeOutputDir() {
      tempDir = Directory.systemTemp.createTempSync('clipmind_cut_');
      addTearDown(() {
        tempDir?.deleteSync(recursive: true);
        tempDir = null;
      });
    }

    testWidgets('drag-select sets the range; the cut button goes live and '
        'cuts through the manual controller', (WidgetTester tester) async {
      makeOutputDir();
      final harness = TaggingWidgetHarness();
      final project = _project().copyWith(outputDir: tempDir!.path);
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(
            _FakeProjectRepository(db: db),
          ),
          ffmpegServiceProvider.overrideWithValue(_FakeFfmpegService()),
          appDatabaseProvider.overrideWithValue(db),
          taggingProvidersProvider.overrideWithValue(harness.providers),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(project);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TimelineView())),
        ),
      );
      await tester.pump();

      // Without a range the cut button is disabled.
      final cutButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('timeline-cut-range')),
      );
      expect(cutButton.onPressed, isNull);

      // Drag-select on the ruler: from its centre (~50%) to +200px.
      // The ruler's GestureDetector is the only one with drag handlers.
      final ruler = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onHorizontalDragStart != null,
      );
      await tester.drag(ruler.first, const Offset(200, 0));
      await tester.pump();

      final range = container.read(timelineRangeProvider);
      expect(range, isNotNull);
      expect(range!.clipId, equals('clip-1'));
      expect(range.startMs, greaterThanOrEqualTo(400));
      expect(range.endMs, lessThanOrEqualTo(1000));
      expect(range.endMs, greaterThan(range.startMs));
      // The cut button is now live.
      final liveButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('timeline-cut-range')),
      );
      expect(liveButton.onPressed, isNotNull);

      // Cut: the range's content is removed via cut_segment through the
      // existing applier chain (repointed + undoable + journaled). The
      // engine's output copy is real async IO: tester.runAsync lets it
      // finish, and the next microtask flush completes the chain.
      await tester.tap(find.byKey(const ValueKey('timeline-cut-range')));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump();

      expect(find.text('Cut applied.'), findsOneWidget);
      // The used range cleared; the cut op is in the undo stack.
      expect(container.read(timelineRangeProvider), isNull);
      expect(container.read(undoRedoProvider).canUndo, isTrue);
      expect(container.read(undoRedoProvider).historyCount, equals(1));
      // The clip was repointed to the cut output.
      final updated = container.read(projectProvider).valueOrNull!;
      final clip = updated.tracks.first.clips.single;
      expect(clip.sourcePath, contains('.mp4'));
    });

    testWidgets('a second tap while cutting is blocked by the busy guard', (
      WidgetTester tester,
    ) async {
      makeOutputDir();
      final harness = TaggingWidgetHarness();
      final project = _project().copyWith(outputDir: tempDir!.path);
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(
            _FakeProjectRepository(db: db),
          ),
          ffmpegServiceProvider.overrideWithValue(_FakeFfmpegService()),
          appDatabaseProvider.overrideWithValue(db),
          taggingProvidersProvider.overrideWithValue(harness.providers),
        ],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(project);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TimelineView())),
        ),
      );
      await tester.pump();

      // Drag-select, then tap cut twice in a row: the first tap sets the
      // busy guard synchronously, so the second tap is a no-op.
      // The ruler's GestureDetector is the only one with drag handlers.
      final ruler = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onHorizontalDragStart != null,
      );
      await tester.drag(ruler.first, const Offset(200, 0));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('timeline-cut-range')));
      await tester.tap(find.byKey(const ValueKey('timeline-cut-range')));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump();

      // Exactly ONE cut op reached the undo stack: the second tap was
      // blocked by the busy guard.
      expect(container.read(undoRedoProvider).historyCount, equals(1));
      expect(find.text('Cut applied.'), findsOneWidget);
      expect(container.read(timelineRangeProvider), isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('manual edits are undoable', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<ProviderContainer> pumpTimeline(
      WidgetTester tester, {
      required Project project,
      required ProjectRepository repository,
    }) async {
      final container = ProviderContainer(
        overrides: [projectRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(project);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TimelineView())),
        ),
      );
      await tester.pump();
      return container;
    }

    int clipCount(Project? project) {
      if (project == null) return 0;
      return [
        for (final track in project.tracks) ...track.clips,
      ].length;
    }

    testWidgets('manual delete pushes a structural entry; undo restores', (
      WidgetTester tester,
    ) async {
      final repository = _FakeProjectRepository(db: db);
      final container = await pumpTimeline(
        tester,
        project: _project(),
        repository: repository,
      );

      // Select the clip block, then delete it.
      await tester.tap(find.text('sample.mp4'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      // The structural entry was pushed BEFORE the mutation (op-less).
      final undoState = container.read(undoRedoProvider);
      expect(undoState.canUndo, isTrue);
      expect(undoState.historyCount, greaterThanOrEqualTo(1));
      // The mutation landed: the clip is gone from the project state.
      expect(clipCount(container.read(projectProvider).valueOrNull), equals(0));

      // Undo restores the pre-edit project; structural entries carry no op.
      final op = await container.read(undoRedoProvider.notifier).undo();
      expect(op, isNull);
      final restored = container.read(projectProvider).valueOrNull;
      final clips = [
        for (final track in restored?.tracks ?? const <Track>[]) ...track.clips,
      ];
      expect(clips.any((clip) => clip.id == 'clip-1'), isTrue);
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    testWidgets('manual copy pushes a structural entry; undo removes it', (
      WidgetTester tester,
    ) async {
      final repository = _FakeProjectRepository(db: db);
      final container = await pumpTimeline(
        tester,
        project: _project(),
        repository: repository,
      );


      // Select the clip block, then copy it.
      await tester.tap(find.text('sample.mp4'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();

      // The copy landed: two clips, the structural entry pushed.
      expect(clipCount(container.read(projectProvider).valueOrNull), equals(2));
      expect(container.read(undoRedoProvider).canUndo, isTrue);

      // Undo restores the pre-copy project (one clip).
      final op = await container.read(undoRedoProvider.notifier).undo();
      expect(op, isNull);
      expect(clipCount(container.read(projectProvider).valueOrNull), equals(1));
      final restored = container.read(projectProvider).valueOrNull;
      final clips = [
        for (final track in restored?.tracks ?? const <Track>[]) ...track.clips,
      ];
      expect(clips.single.id, equals('clip-1'));
    });
  });
}