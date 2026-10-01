import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/state/manual_edit_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';

/// D8 tests: `submitTrim`/`submitSplit` run through the structural applier
/// (`trimClip`/`splitClip`), so — like the structural flow tests — they
/// need no FFmpeg: memory DB + recording repository + `setProject`.
///
/// Time conventions under test:
/// - `submitTrim` takes LOCAL source times (the clip's new in/out — what
///   the trim handles drag).
/// - `submitSplit` takes PROJECT timeline time (the playhead position,
///   passed straight through); the controller converts to the SOURCE
///   split point (`atProjectMs − clip.positionMs + clip.startMs`) for
///   `at_local_ms`.
class _RecordingRepository extends ProjectRepository {
  int saves = 0;

  _RecordingRepository(super.db);

  @override
  Future<void> save(Project project) async {
    saves++;
  }
}

Project _project() {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['/v/a.mp4'],
    tracks: [
      const Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip_1',
            trackId: 't1',
            sourcePath: '/v/a.mp4',
            startMs: 0,
            endMs: 60000,
            positionMs: 0,
          ),
          Clip(
            id: 'clip_2',
            trackId: 't1',
            sourcePath: '/v/b.mp4',
            startMs: 0,
            endMs: 30000,
            positionMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: 90000,
    outputDir: '/out',
  );
}

List<Clip> _clips(ProviderContainer container) => container
    .read(projectProvider)
    .value!
    .tracks
    .firstWhere((t) => t.id == 't1')
    .clips;

EditOperation _lastJournaled(ProviderContainer container) => container
    .read(projectProvider)
    .value!
    .editHistory
    .last;

void main() {
  late AppDatabase db;
  late _RecordingRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = _RecordingRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer makeContainer({bool withProject = true}) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        projectRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    if (withProject) {
      container.read(projectProvider.notifier).setProject(_project());
    }
    return container;
  }

  group('submitTrim (D8, local source times)', () {
    test('unknown clip fails without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitTrim(clipId: 'ghost', startMs: 0, endMs: 1000);

      expect(result.success, isFalse);
      expect(result.message, contains('Unknown clip'));
      expect(container.read(undoRedoProvider).canUndo, isFalse);
      expect(_clips(container).length, equals(2));
    });

    test('no project fails gracefully', () async {
      final container = makeContainer(withProject: false);
      final result = await container
          .read(manualEditControllerProvider)
          .submitTrim(clipId: 'clip_1', startMs: 0, endMs: 1000);

      expect(result.success, isFalse);
      expect(result.message, contains('No project'));
    });

    test('inverted range fails without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitTrim(clipId: 'clip_1', startMs: 9000, endMs: 1000);

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid trim range'));
      expect(container.read(undoRedoProvider).canUndo, isFalse);
      expect(_clips(container).first.startMs, equals(0));
    });

    test('trims in/out, repins the ripple, journals, and undoes', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitTrim(clipId: 'clip_1', startMs: 10000, endMs: 50000);

      expect(result.success, isTrue);
      expect(result.message, equals('Trimmed clip "clip_1".'));
      // No FFmpeg runs for structural ops: no output file.
      expect(result.outputPath, isNull);
      final clips = _clips(container);
      expect(clips.first.startMs, equals(10000));
      expect(clips.first.endMs, equals(50000));
      // Repin ripple: clip_2 follows the trimmed 40s clip.
      expect(clips[1].positionMs, equals(40000));
      // Journaled as trimClip with the backend's param names.
      final journaled = _lastJournaled(container);
      expect(journaled.type, equals(EditOperationType.trimClip));
      expect(
        journaled.params,
        equals({'clip_id': 'clip_1', 'start_ms': 10000, 'end_ms': 50000}),
      );
      expect(container.read(undoRedoProvider).canUndo, isTrue);

      await container.read(undoRedoProvider.notifier).undo();
      final restored = _clips(container);
      expect(restored.first.startMs, equals(0));
      expect(restored.first.endMs, equals(60000));
      expect(restored[1].positionMs, equals(60000));
    });
  });

  group('submitSplit (D8, project time + controller conversion)', () {
    test('unknown clip fails without side effects', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitSplit(clipId: 'ghost', atProjectMs: 5000);

      expect(result.success, isFalse);
      expect(result.message, contains('Unknown clip'));
      expect(container.read(undoRedoProvider).canUndo, isFalse);
    });

    test('no project fails gracefully', () async {
      final container = makeContainer(withProject: false);
      final result = await container
          .read(manualEditControllerProvider)
          .submitSplit(clipId: 'clip_1', atProjectMs: 5000);

      expect(result.success, isFalse);
      expect(result.message, contains('No project'));
    });

    test('playhead outside the clip span fails without side effects',
        () async {
      final container = makeContainer();
      final controller = container.read(manualEditControllerProvider);

      final before = await controller.submitSplit(
        clipId: 'clip_1',
        atProjectMs: 70000,
      );
      expect(before.success, isFalse);
      expect(before.message, contains('outside the clip'));

      final atEdge = await controller.submitSplit(
        clipId: 'clip_1',
        atProjectMs: 0,
      );
      expect(atEdge.success, isFalse);

      expect(container.read(undoRedoProvider).canUndo, isFalse);
      expect(_clips(container).length, equals(2));
    });

    test('playhead too close to the edges fails actionably', () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitSplit(clipId: 'clip_1', atProjectMs: 10);

      expect(result.success, isFalse);
      expect(result.message, contains('too close'));
      expect(container.read(undoRedoProvider).canUndo, isFalse);
      expect(_clips(container).length, equals(2));
    });

    test('splits into two same-source clips, repins, journals, undoes',
        () async {
      final container = makeContainer();
      final result = await container
          .read(manualEditControllerProvider)
          .submitSplit(clipId: 'clip_1', atProjectMs: 20000);

      expect(result.success, isTrue);
      expect(result.message, equals('Split clip "clip_1" at the playhead.'));
      expect(result.outputPath, isNull);
      final clips = _clips(container);
      expect(clips.length, equals(3));
      // The two halves share the original source and partition it.
      expect(clips[0].id, equals('clip_1'));
      expect(clips[0].startMs, equals(0));
      expect(clips[0].endMs, equals(20000));
      expect(clips[1].sourcePath, equals('/v/a.mp4'));
      expect(clips[1].startMs, equals(20000));
      expect(clips[1].endMs, equals(60000));
      expect(
        clips.take(2).map((c) => c.positionMs).toList(),
        equals([0, 20000]),
      );
      // The follower repins after the split.
      expect(clips[2].id, equals('clip_2'));
      expect(clips[2].positionMs, equals(60000));
      // The controller converted project → local for the op params.
      final journaled = _lastJournaled(container);
      expect(journaled.type, equals(EditOperationType.splitClip));
      expect(
        journaled.params,
        equals({'clip_id': 'clip_1', 'at_local_ms': 20000}),
      );
      expect(container.read(undoRedoProvider).canUndo, isTrue);

      await container.read(undoRedoProvider.notifier).undo();
      expect(_clips(container).map((c) => c.id).toList(),
          equals(['clip_1', 'clip_2']));
    });

    test('project→local conversion subtracts clip.positionMs', () async {
      final container = makeContainer();
      // clip_2 sits at positionMs 60000: project 70000 == local 10000.
      final result = await container
          .read(manualEditControllerProvider)
          .submitSplit(clipId: 'clip_2', atProjectMs: 70000);

      expect(result.success, isTrue);
      final journaled = _lastJournaled(container);
      expect(journaled.type, equals(EditOperationType.splitClip));
      expect(journaled.params['at_local_ms'], equals(10000));
      final clips = _clips(container);
      expect(clips.length, equals(3));
      expect(clips[1].startMs, equals(0));
      expect(clips[1].endMs, equals(10000));
      expect(clips[2].startMs, equals(10000));
      expect(clips[2].endMs, equals(30000));
      expect(clips[2].sourcePath, equals('/v/b.mp4'));
    });

    test('previously-trimmed clip splits at the source offset', () async {
      final container = makeContainer();
      final trim = await container
          .read(manualEditControllerProvider)
          .submitTrim(clipId: 'clip_1', startMs: 5000, endMs: 60000);
      expect(trim.success, isTrue);

      // Timeline offset 20000 into the clip, but the source offset adds
      // the trimmed head: 20000 − 0 + 5000 == 25000.
      final result = await container
          .read(manualEditControllerProvider)
          .submitSplit(clipId: 'clip_1', atProjectMs: 20000);

      expect(result.success, isTrue);
      final journaled = _lastJournaled(container);
      expect(journaled.type, equals(EditOperationType.splitClip));
      expect(journaled.params['at_local_ms'], equals(25000));
      final clips = _clips(container);
      expect(clips.length, equals(3));
      expect(clips[0].id, equals('clip_1'));
      expect(clips[0].startMs, equals(5000));
      expect(clips[0].endMs, equals(25000));
      expect(clips[1].startMs, equals(25000));
      expect(clips[1].endMs, equals(60000));
      expect(clips[1].sourcePath, equals('/v/a.mp4'));
      expect(
        clips.take(2).map((c) => c.positionMs).toList(),
        equals([0, 20000]),
      );
      expect(clips[2].id, equals('clip_2'));
      expect(clips[2].positionMs, equals(55000));
    });
  });
}
