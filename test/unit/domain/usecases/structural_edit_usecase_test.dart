import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/domain/usecases/structural_edit_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

Clip _clip(String id, int startMs, int endMs, {int positionMs = 0}) {
  return Clip(
    id: id,
    trackId: 't1',
    sourcePath: '/v/$id.mp4',
    startMs: startMs,
    endMs: endMs,
    positionMs: positionMs,
  );
}

Project _project(List<Clip> clips) {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['/v/a.mp4'],
    tracks: [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: clips,
      ),
    ],
    durationMs: 90000,
    outputDir: '/out',
  );
}

EditOperation _op(
  EditOperationType type, [
  Map<String, dynamic> params = const {},
]) {
  return EditOperation(
    id: 'op_1',
    type: type,
    createdAt: DateTime(2026, 1, 1),
    params: params,
  );
}

List<String> _ids(Project project) =>
    project.tracks.single.clips.map((c) => c.id).toList();

List<int> _positions(Project project) =>
    project.tracks.single.clips.map((c) => c.positionMs).toList();

void main() {
  const useCase = StructuralEditUseCase();

  group('deleteClip', () {
    test('removes the clip and repins the track (ripple, no gaps)', () {
      final project = _project([
        _clip('a', 0, 10000, positionMs: 0),
        _clip('b', 0, 10000, positionMs: 10000),
        _clip('c', 0, 10000, positionMs: 20000),
      ]);

      final result = useCase.apply(
        _op(EditOperationType.deleteClip, {'clip_id': 'b'}),
        project,
      );

      expect(result, isNotNull);
      expect(_ids(result!), equals(['a', 'c']));
      // Ripple: positions are recomputed cumulatively from 0 so the
      // timeline and the export agree (no gap artifacts).
      expect(_positions(result), equals([0, 10000]));
    });

    test('deleting the first clip repins survivors from 0', () {
      final project = _project([
        _clip('a', 0, 10000, positionMs: 0),
        _clip('b', 0, 5000, positionMs: 10000),
        _clip('c', 0, 20000, positionMs: 15000),
      ]);

      final result = useCase.apply(
        _op(EditOperationType.deleteClip, {'clip_id': 'a'}),
        project,
      );

      expect(result, isNotNull);
      expect(_ids(result!), equals(['b', 'c']));
      expect(_positions(result), equals([0, 5000]));
    });

    test('unknown or missing clip id returns null', () {
      final project = _project([_clip('a', 0, 1000)]);
      expect(
        useCase.apply(_op(EditOperationType.deleteClip, {'clip_id': 'zz'}),
            project),
        isNull,
      );
      expect(
        useCase.apply(_op(EditOperationType.deleteClip), project),
        isNull,
      );
    });
  });

  group('copyClip', () {
    test('duplicates after the original with a fresh id and end position',
        () {
      final project = _project([
        _clip('a', 0, 10000, positionMs: 0),
        _clip('b', 0, 5000, positionMs: 10000),
      ]);

      final result = useCase.apply(
        _op(EditOperationType.copyClip, {'clip_id': 'a'}),
        project,
      );

      expect(result, isNotNull);
      expect(_ids(result!), equals(['a', 'a_copy_1', 'b']));
      final copy = result.tracks.single.clips[1];
      expect(copy.positionMs, equals(10000));
      expect(copy.sourcePath, equals('/v/a.mp4'));
      expect(copy.startMs, equals(0));
      expect(copy.endMs, equals(10000));
    });

    test('copy ids stay unique across repeated copies', () {
      var project = _project([_clip('a', 0, 1000)]);
      project = useCase.apply(
        _op(EditOperationType.copyClip, {'clip_id': 'a'}),
        project,
      )!;
      final again = useCase.apply(
        _op(EditOperationType.copyClip, {'clip_id': 'a'}),
        project,
      );

      // Each copy lands directly after the original with a fresh id.
      expect(_ids(again!), equals(['a', 'a_copy_2', 'a_copy_1']));
    });

    test('caller-supplied new_clip_id wins; collisions return null', () {
      final project = _project([
        _clip('a', 0, 1000),
        _clip('b', 0, 1000),
      ]);

      final ok = useCase.apply(
        _op(EditOperationType.copyClip,
            {'clip_id': 'a', 'new_clip_id': 'a2'}),
        project,
      );
      expect(_ids(ok!), equals(['a', 'a2', 'b']));

      expect(
        useCase.apply(
          _op(EditOperationType.copyClip,
              {'clip_id': 'a', 'new_clip_id': 'b'}),
          project,
        ),
        isNull,
      );
    });

    test('unknown clip returns null', () {
      final project = _project([_clip('a', 0, 1000)]);
      expect(
        useCase.apply(
            _op(EditOperationType.copyClip, {'clip_id': 'zz'}), project),
        isNull,
      );
    });
  });

  group('moveClip', () {
    test('reorders and recomputes positionMs cumulatively', () {
      final project = _project([
        _clip('a', 0, 10000, positionMs: 0),
        _clip('b', 0, 5000, positionMs: 10000),
        _clip('c', 0, 20000, positionMs: 15000),
      ]);

      final result = useCase.apply(
        _op(EditOperationType.moveClip,
            {'clip_id': 'c', 'after_clip_id': 'a'}),
        project,
      );

      expect(result, isNotNull);
      expect(_ids(result!), equals(['a', 'c', 'b']));
      expect(_positions(result), equals([0, 10000, 30000]));
    });

    test('null after_clip_id moves to front', () {
      final project = _project([
        _clip('a', 0, 10000, positionMs: 0),
        _clip('b', 0, 5000, positionMs: 10000),
      ]);

      final result = useCase.apply(
        _op(EditOperationType.moveClip, {'clip_id': 'b'}),
        project,
      );

      expect(_ids(result!), equals(['b', 'a']));
      expect(_positions(result), equals([0, 5000]));
    });

    test('moving after itself is a no-op returning the project', () {
      final project = _project([
        _clip('a', 0, 10000, positionMs: 0),
        _clip('b', 0, 5000, positionMs: 10000),
      ]);

      final result = useCase.apply(
        _op(EditOperationType.moveClip,
            {'clip_id': 'a', 'after_clip_id': 'a'}),
        project,
      );

      expect(identical(result, project), isTrue);
    });

    test('unknown clips return null', () {
      final project = _project([_clip('a', 0, 1000)]);
      expect(
        useCase.apply(
            _op(EditOperationType.moveClip, {'clip_id': 'zz'}), project),
        isNull,
      );
      expect(
        useCase.apply(
            _op(EditOperationType.moveClip,
                {'clip_id': 'a', 'after_clip_id': 'zz'}),
            project),
        isNull,
      );
    });
  });

  group('trimClip', () {
    test('shrinks the range and stamps the original bounds', () {
      final project = _project([_clip('a', 0, 10000, positionMs: 0)]);

      final result = useCase.apply(
        _op(EditOperationType.trimClip,
            {'clip_id': 'a', 'start_ms': 2000, 'end_ms': 8000}),
        project,
      );

      expect(result, isNotNull);
      final clip = result!.tracks.single.clips.single;
      expect(clip.startMs, equals(2000));
      expect(clip.endMs, equals(8000));
      expect(clip.positionMs, equals(0));
      expect(clip.transformations['original_start_ms'], equals(0));
      expect(clip.transformations['original_end_ms'], equals(10000));
    });

    test('repins the track cumulatively (ripple)', () {
      final project = _project([
        _clip('a', 0, 10000, positionMs: 0),
        _clip('b', 0, 5000, positionMs: 10000),
      ]);

      final result = useCase.apply(
        _op(EditOperationType.trimClip,
            {'clip_id': 'a', 'start_ms': 2000, 'end_ms': 8000}),
        project,
      );

      expect(result, isNotNull);
      expect(_ids(result!), equals(['a', 'b']));
      // `a` now spans 6000ms, so `b` shifts from 10000 to 6000.
      expect(_positions(result), equals([0, 6000]));
    });

    test('in/out validation returns null', () {
      final project = _project([_clip('a', 0, 10000)]);
      final cases = <Map<String, dynamic>>[
        // start >= end.
        {'clip_id': 'a', 'start_ms': 5000, 'end_ms': 5000},
        {'clip_id': 'a', 'start_ms': 6000, 'end_ms': 1000},
        // negative start.
        {'clip_id': 'a', 'start_ms': -100, 'end_ms': 1000},
        // below the minimum clip duration.
        {'clip_id': 'a', 'start_ms': 100, 'end_ms': 120},
        // missing params.
        {'clip_id': 'a', 'start_ms': 100},
        {'clip_id': 'a', 'end_ms': 1000},
        {'start_ms': 100, 'end_ms': 1000},
        // unknown clip.
        {'clip_id': 'zz', 'start_ms': 100, 'end_ms': 1000},
      ];
      for (final params in cases) {
        expect(
          useCase.apply(_op(EditOperationType.trimClip, params), project),
          isNull,
          reason: params.toString(),
        );
      }
    });

    test('handles may move outward up to the original', () {
      var project = _project([_clip('a', 0, 10000)]);
      project = useCase.apply(
        _op(EditOperationType.trimClip,
            {'clip_id': 'a', 'start_ms': 2000, 'end_ms': 8000}),
        project,
      )!;

      // Outward within the stamped range is allowed ...
      final grown = useCase.apply(
        _op(EditOperationType.trimClip,
            {'clip_id': 'a', 'start_ms': 0, 'end_ms': 10000}),
        project,
      );

      expect(grown, isNotNull);
      final clip = grown!.tracks.single.clips.single;
      expect(clip.startMs, equals(0));
      expect(clip.endMs, equals(10000));
      // ... and the stamp still marks the true original.
      expect(clip.transformations['original_start_ms'], equals(0));
      expect(clip.transformations['original_end_ms'], equals(10000));
    });

    test('growing beyond the original returns null', () {
      var project = _project([_clip('a', 0, 10000)]);
      project = useCase.apply(
        _op(EditOperationType.trimClip,
            {'clip_id': 'a', 'start_ms': 2000, 'end_ms': 8000}),
        project,
      )!;

      // In/out-valid ranges that exceed the stamped original.
      expect(
        useCase.apply(
          _op(EditOperationType.trimClip,
              {'clip_id': 'a', 'start_ms': 2000, 'end_ms': 10001}),
          project,
        ),
        isNull,
      );
      // A stamped start above zero (via split below) also bounds the
      // handle: [4000, 10000] split off, shrunk, then pushed past it.
      var split = useCase.apply(
        _op(EditOperationType.splitClip,
            {'clip_id': 'a', 'at_local_ms': 4000}),
        _project([_clip('a', 0, 10000)]),
      )!;
      split = useCase.apply(
        _op(EditOperationType.trimClip,
            {'clip_id': 'a_copy_1', 'start_ms': 5000, 'end_ms': 9000}),
        split,
      )!;
      expect(
        useCase.apply(
          _op(EditOperationType.trimClip,
              {'clip_id': 'a_copy_1', 'start_ms': 3000, 'end_ms': 9000}),
          split,
        ),
        isNull,
      );
    });

    test('corrupt stamped bounds fail closed', () {
      final stamped = _clip('a', 3000, 7000).copyWith(transformations: {
        'original_start_ms': 'bogus',
        'original_end_ms': 8000,
      });
      final project = _project([stamped]);

      expect(
        useCase.apply(
          _op(EditOperationType.trimClip,
              {'clip_id': 'a', 'start_ms': 3000, 'end_ms': 6000}),
          project,
        ),
        isNull,
      );
    });

    test('numeric-string params are accepted', () {
      final project = _project([_clip('a', 0, 10000)]);

      final result = useCase.apply(
        _op(EditOperationType.trimClip,
            {'clip_id': 'a', 'start_ms': '2000', 'end_ms': 8000.0}),
        project,
      );

      expect(result, isNotNull);
      final clip = result!.tracks.single.clips.single;
      expect(clip.startMs, equals(2000));
      expect(clip.endMs, equals(8000));
    });
  });

  group('splitClip', () {
    test('divides the clip into two sharing the source', () {
      final project = _project([_clip('a', 0, 10000, positionMs: 0)]);

      final result = useCase.apply(
        _op(EditOperationType.splitClip,
            {'clip_id': 'a', 'at_local_ms': 4000}),
        project,
      );

      expect(result, isNotNull);
      final clips = result!.tracks.single.clips;
      expect(clips.map((c) => c.id).toList(), equals(['a', 'a_copy_1']));
      expect(clips[0].startMs, equals(0));
      expect(clips[0].endMs, equals(4000));
      expect(clips[1].startMs, equals(4000));
      expect(clips[1].endMs, equals(10000));
      expect(clips[1].sourcePath, equals(clips[0].sourcePath));
      expect(clips[1].sourcePath, equals('/v/a.mp4'));
      expect(_positions(result), equals([0, 4000]));
    });

    test('repins later clips after the split (ripple)', () {
      final project = _project([
        _clip('a', 0, 10000, positionMs: 0),
        _clip('b', 0, 5000, positionMs: 10000),
      ]);

      final result = useCase.apply(
        _op(EditOperationType.splitClip,
            {'clip_id': 'a', 'at_local_ms': 4000}),
        project,
      );

      expect(result, isNotNull);
      expect(_ids(result!), equals(['a', 'a_copy_1', 'b']));
      expect(_positions(result), equals([0, 4000, 10000]));
    });

    test('first half keeps id and transformations', () {
      var project = _project([_clip('a', 0, 10000)]);
      project = useCase.apply(
        _op(EditOperationType.trimClip,
            {'clip_id': 'a', 'start_ms': 2000, 'end_ms': 8000}),
        project,
      )!;

      final result = useCase.apply(
        _op(EditOperationType.splitClip,
            {'clip_id': 'a', 'at_local_ms': 5000}),
        project,
      );

      expect(result, isNotNull);
      final clips = result!.tracks.single.clips;
      expect(clips[0].id, equals('a'));
      expect(clips[0].startMs, equals(2000));
      expect(clips[0].endMs, equals(5000));
      expect(clips[0].transformations['original_start_ms'], equals(0));
      expect(clips[1].startMs, equals(5000));
      expect(clips[1].endMs, equals(8000));
      expect(clips[1].transformations['original_start_ms'], equals(0));
      expect(clips[1].transformations['original_end_ms'], equals(10000));
    });

    test('split ids stay unique like copies', () {
      final project = _project([
        _clip('a', 0, 10000),
        _clip('a_copy_1', 0, 10000),
      ]);

      final result = useCase.apply(
        _op(EditOperationType.splitClip,
            {'clip_id': 'a', 'at_local_ms': 4000}),
        project,
      );

      expect(_ids(result!), equals(['a', 'a_copy_2', 'a_copy_1']));
    });

    test('points within 50ms of an edge return null', () {
      final project = _project([_clip('a', 0, 10000)]);
      final cases = <Map<String, dynamic>>[
        {'clip_id': 'a', 'at_local_ms': 0},
        {'clip_id': 'a', 'at_local_ms': 10000},
        {'clip_id': 'a', 'at_local_ms': 49},
        {'clip_id': 'a', 'at_local_ms': 9951},
        {'clip_id': 'a', 'at_local_ms': -10},
        {'clip_id': 'a', 'at_local_ms': 20000},
        {'clip_id': 'a'},
        {'clip_id': 'zz', 'at_local_ms': 4000},
      ];
      for (final params in cases) {
        expect(
          useCase.apply(_op(EditOperationType.splitClip, params), project),
          isNull,
          reason: params.toString(),
        );
      }
    });

    test('exactly 50ms from an edge is allowed', () {
      final project = _project([_clip('a', 0, 10000)]);

      final atStart = useCase.apply(
        _op(EditOperationType.splitClip,
            {'clip_id': 'a', 'at_local_ms': 50}),
        project,
      );
      expect(atStart, isNotNull);
      expect(
        atStart!.tracks.single.clips.map((c) => c.endMs - c.startMs).toList(),
        equals([50, 9950]),
      );

      final atEnd = useCase.apply(
        _op(EditOperationType.splitClip,
            {'clip_id': 'a', 'at_local_ms': 9950}),
        project,
      );
      expect(atEnd, isNotNull);
      expect(
        atEnd!.tracks.single.clips.map((c) => c.endMs - c.startMs).toList(),
        equals([9950, 50]),
      );
    });
  });

  group('non-structural ops', () {
    test('ffmpeg op types return null', () {
      final project = _project([_clip('a', 0, 1000)]);
      for (final type in [
        EditOperationType.trim,
        EditOperationType.addTransition,
        EditOperationType.applyEffect,
      ]) {
        expect(
          useCase.apply(_op(type, {'clip_id': 'a'}), project),
          isNull,
          reason: type.name,
        );
      }
    });
  });
}
