import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/data/atomic_project_file_store.dart';
import 'package:clipmind/features/projects/data/project_document_codec.dart';
import 'package:clipmind/features/projects/domain/transactions/project_file_write_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';
import '../support/project_test_data.dart';

void main() {
  const path = r'C:\projects\demo.cmproj';
  String validJson([int revision = 0]) => ProjectDocumentCodec().encodeJson(
    documentWithOneClip(revision: revision),
  );
  AtomicProjectFileStore store(MemoryProjectFileIo io) =>
      AtomicProjectFileStore(io, validator: ProjectDocumentCodec());

  test('flush failure leaves the old target unchanged', () async {
    final old = validJson();
    final io = MemoryProjectFileIo({path: old})
      ..failurePoints.add(FileIoFailure.flush);
    final result = await store(io).writeJson(path, validJson(1));
    expect(result, isA<Failure<ProjectFileWriteOutcome>>());
    expect(io.files[path], old);
  });

  test('migration backup-copy failure preserves the target', () async {
    final old = validJson();
    final io = MemoryProjectFileIo({path: old})
      ..failurePoints.add(FileIoFailure.copy);
    final result = await store(
      io,
    ).writeJson(path, validJson(1), migrationFromSchema: 1);
    expect(result, isA<Failure<ProjectFileWriteOutcome>>());
    expect(io.files[path], old);
    expect(io.files.containsKey('$path.v1.bak'), isFalse);
  });

  test('target-to-rollback failure preserves target bytes', () async {
    final old = validJson();
    final io = MemoryProjectFileIo({path: old})
      ..failurePoints.add(FileIoFailure.targetToRollback);
    final result = await store(io).writeJson(path, validJson(1));
    expect(result, isA<Failure<ProjectFileWriteOutcome>>());
    expect(io.files[path], old);
  });

  test('temp promotion failure restores rollback to target', () async {
    final old = validJson();
    final io = MemoryProjectFileIo({path: old})
      ..failurePoints.add(FileIoFailure.promote);
    final result = await store(io).writeJson(path, validJson(1));
    expect(result, isA<Failure<ProjectFileWriteOutcome>>());
    expect(io.files[path], old);
    expect(io.files.containsKey('$path.rollback'), isFalse);
  });

  test('rollback restoration failure retains recovery evidence', () async {
    final old = validJson();
    final io = MemoryProjectFileIo({path: old})
      ..failurePoints.addAll({FileIoFailure.promote, FileIoFailure.restore});
    final result = await store(io).writeJson(path, validJson(1));
    expect(result, isA<Failure<ProjectFileWriteOutcome>>());
    expect(io.files.containsKey('$path.rollback'), isTrue);
    expect(io.operations, [
      'write:$path.tmp',
      'rename:$path:$path.rollback',
      'rename:$path.tmp:$path',
      'rename:$path.rollback:$path',
    ]);
  });

  test('stale rollback is discarded only after target validates', () async {
    final io = MemoryProjectFileIo({
      path: validJson(),
      '$path.rollback': validJson(1),
    });
    final result = await store(io).recover(path);
    expect(result, isA<Success<ProjectReadResult>>());
    expect(io.files[path], validJson());
    expect(io.files.containsKey('$path.rollback'), isFalse);
  });

  test('missing target recovers rollback bytes', () async {
    final old = validJson();
    final io = MemoryProjectFileIo({'$path.rollback': old});
    final result = await store(io).recover(path);
    expect(result, isA<Success<ProjectReadResult>>());
    expect(io.files[path], old);
    expect(
      (result as Success<ProjectReadResult>).value.recoveredFromRollback,
      isTrue,
    );
  });

  test(
    'invalid target preserves rollback evidence rather than deleting it',
    () async {
      final rollback = validJson();
      final io = MemoryProjectFileIo({
        path: '{not-json',
        '$path.rollback': rollback,
      });
      final result = await store(io).recover(path);
      expect(result, isA<Failure<ProjectReadResult>>());
      expect(io.files[path], '{not-json');
      expect(io.files['$path.rollback'], rollback);
    },
  );

  test(
    'missing target with invalid rollback preserves rollback evidence',
    () async {
      final io = MemoryProjectFileIo({'$path.rollback': '{not-json'});
      final result = await store(io).recover(path);
      expect(result, isA<Failure<ProjectReadResult>>());
      expect(io.files.containsKey(path), isFalse);
      expect(io.files['$path.rollback'], '{not-json');
    },
  );

  test(
    'valid target with stale rollback cleanup failure is a warning success',
    () async {
      final target = validJson();
      final io = MemoryProjectFileIo({
        path: target,
        '$path.rollback': validJson(1),
      })..failurePoints.add(FileIoFailure.cleanup);
      final result = await store(io).recover(path);
      final read = (result as Success<ProjectReadResult>).value;
      expect(read.json, target);
      expect(read.warnings.single.code, 'rollback_cleanup_failed');
      expect(io.files[path], target);
      expect(io.files.containsKey('$path.rollback'), isTrue);
    },
  );

  test(
    'cleanup failure returns durable success with rollback cleanup warning',
    () async {
      final old = validJson();
      final next = validJson(1);
      final io = MemoryProjectFileIo({path: old})
        ..failurePoints.add(FileIoFailure.cleanup);
      final result = await store(io).writeJson(path, next);
      final outcome = (result as Success<ProjectFileWriteOutcome>).value;
      expect(outcome.warning!.code, 'rollback_cleanup_failed');
      expect(io.files[path], next);
      expect(io.files.containsKey('$path.rollback'), isTrue);
    },
  );

  test('migration retains versioned backup beside Windows target', () async {
    final old = validJson();
    final next = validJson(1);
    final io = MemoryProjectFileIo({path: old});
    final result = await store(
      io,
    ).writeJson(path, next, migrationFromSchema: 1);
    expect(result, isA<Success<ProjectFileWriteOutcome>>());
    expect(io.files[path], next);
    expect(io.files['$path.v1.bak'], old);
  });

  test('new target writes without a rollback file', () async {
    final next = validJson();
    final io = MemoryProjectFileIo();
    final result = await store(io).writeJson(path, next);
    expect(result, isA<Success<ProjectFileWriteOutcome>>());
    expect(io.files[path], next);
    expect(io.files.containsKey('$path.rollback'), isFalse);
  });
}
