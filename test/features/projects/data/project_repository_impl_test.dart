import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/data/atomic_project_file_store.dart';
import 'package:clipmind/features/projects/data/project_document_codec.dart';
import 'package:clipmind/features/projects/data/project_repository_impl.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';
import '../support/project_test_data.dart';

void main() {
  const path = r'C:\projects\project-1.cmproj';

  ProjectRepositoryImpl repository(
    MemoryProjectFileIo files,
    FakeProjectIndex index,
  ) => ProjectRepositoryImpl(
    fileStore: AtomicProjectFileStore(files, validator: ProjectDocumentCodec()),
    codec: ProjectDocumentCodec(),
    index: index,
    pathFor: (ProjectDocument _) => path,
  );

  test('file failure returns Failure and never updates the index', () async {
    final files = MemoryProjectFileIo()..failurePoints.add(FileIoFailure.flush);
    final index = FakeProjectIndex();
    final result = await repository(files, index).save(documentWithOneClip());
    expect(result, isA<Failure<ProjectSaveOutcome>>());
    expect(index.upsertCalls, 0);
  });

  test(
    'file and index success returns saved document without warning',
    () async {
      final files = MemoryProjectFileIo();
      final index = FakeProjectIndex();
      final result = await repository(
        files,
        index,
      ).save(documentWithOneClip(revision: 1));
      final outcome = (result as Success<ProjectSaveOutcome>).value;
      expect(outcome.document.revision, 1);
      expect(outcome.warnings, isEmpty);
      expect(files.files[path], isNotNull);
      expect(index.documents['project-1']!.revision, 1);
    },
  );

  test(
    'file success and index failure remains semantic success with warning',
    () async {
      final files = MemoryProjectFileIo();
      final index = FakeProjectIndex()..failUpsert = true;
      final result = await repository(
        files,
        index,
      ).save(documentWithOneClip(revision: 2));
      final outcome = (result as Success<ProjectSaveOutcome>).value;
      expect(outcome.document.revision, 2);
      expect(outcome.warnings.single.code, 'project_index_upsert_failed');
      expect(files.files[path], isNotNull);
    },
  );

  test(
    'durable result is the exact document returned to the publication layer',
    () async {
      final files = MemoryProjectFileIo();
      final index = FakeProjectIndex()..failUpsert = true;
      final document = documentWithOneClip(revision: 3);
      final outcome =
          ((await repository(files, index).save(document))
                  as Success<ProjectSaveOutcome>)
              .value;
      expect(outcome.document, document);
      expect(outcome.warnings.single.code, 'project_index_upsert_failed');
    },
  );

  test('durable file and index warnings are surfaced together', () async {
    final initial = documentWithOneClip();
    final files = MemoryProjectFileIo({
      path: ProjectDocumentCodec().encodeJson(initial),
    })..failurePoints.add(FileIoFailure.cleanup);
    final index = FakeProjectIndex()..failUpsert = true;
    final result = await repository(
      files,
      index,
    ).save(documentWithOneClip(revision: 4));
    final outcome = (result as Success<ProjectSaveOutcome>).value;
    expect(outcome.document.revision, 4);
    expect(
      outcome.warnings.map((ProjectSaveWarning warning) => warning.code),
      containsAll(['rollback_cleanup_failed', 'project_index_upsert_failed']),
    );
  });
}
