import 'dart:io';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/data/atomic_project_file_store.dart';
import 'package:clipmind/features/projects/data/project_document_codec.dart';
import 'package:clipmind/features/projects/data/project_repository_impl.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';

String fixtureJson(String name) =>
    File('test/fixtures/projects/$name').readAsStringSync();

void main() {
  const path = r'C:\projects\legacy.cmproj';

  ProjectRepositoryImpl repository(
    MemoryProjectFileIo io,
    FakeProjectIndex index,
  ) {
    final codec = ProjectDocumentCodec();
    return ProjectRepositoryImpl(
      fileStore: AtomicProjectFileStore(io, validator: codec),
      codec: codec,
      index: index,
      pathFor: (ProjectDocument _) => path,
    );
  }

  test('v1 load migrates durably and retains versioned backup', () async {
    final original = fixtureJson('legacy_v1_source_media_paths.cmproj');
    final io = MemoryProjectFileIo({path: original});
    final result = await repository(io, FakeProjectIndex()).load(path);
    final outcome = (result as Success<ProjectSaveOutcome>).value;
    expect(outcome.document.schemaVersion, 2);
    expect(io.files['$path.v1.bak'], original);
    expect(io.files[path], contains('"schemaVersion":2'));
  });

  test('migration write failure leaves legacy source bytes intact', () async {
    final original = fixtureJson('legacy_v0_source_paths.cmproj');
    final io = MemoryProjectFileIo({path: original})
      ..failurePoints.add(FileIoFailure.targetToRollback);
    final result = await repository(io, FakeProjectIndex()).load(path);
    expect(result, isA<Failure<ProjectSaveOutcome>>());
    expect(io.files[path], original);
  });

  test('subsequent schema-two load does not create another backup', () async {
    final original = fixtureJson('legacy_v1_source_media_paths.cmproj');
    final io = MemoryProjectFileIo({path: original});
    final first = await repository(io, FakeProjectIndex()).load(path);
    expect(first, isA<Success<ProjectSaveOutcome>>());
    io.operations.clear();
    final second = await repository(io, FakeProjectIndex()).load(path);
    expect(second, isA<Success<ProjectSaveOutcome>>());
    expect(
      io.operations.where((String operation) => operation.startsWith('copy:')),
      isEmpty,
    );
  });
}
