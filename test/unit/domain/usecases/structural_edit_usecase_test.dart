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
    test('removes the clip, leaving siblings untouched', () {
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
      // Deletion artifacts: surviving positions are not renormalized.
      expect(_positions(result), equals([0, 20000]));
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
