import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/track_row.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';

/// Fake repository: the sandbox has no path_provider; the save is a no-op
/// so the mutation reaches the project state and the undo's onRestore
/// completes without file IO. The memory DB is shared from the test's
/// setUp/tearDown so it closes cleanly.
class _FakeProjectRepository extends ProjectRepository {
  _FakeProjectRepository({required AppDatabase db}) : super(db);

  @override
  Future<void> save(Project project) async {}
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
