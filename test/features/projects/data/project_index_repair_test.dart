import 'package:clipmind/features/projects/data/project_index_repair_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';
import '../support/project_test_data.dart';

void main() {
  test(
    'recent-project load rebuilds an empty index from authoritative cmproj documents',
    () async {
      final index = FakeProjectIndex();
      final files = FakeProjectDocumentLocator({
        r'C:\projects\project-1.cmproj': documentWithOneClip(revision: 4),
      });
      final result = await ProjectIndexRepairService(
        index: index,
        documents: files,
      ).rebuildRecent();
      expect(result.repairedPaths, [r'C:\projects\project-1.cmproj']);
      expect(index.documents['project-1']!.revision, 4);
    },
  );

  test('stale index is replaced by the authoritative file revision', () async {
    final index = FakeProjectIndex()
      ..documents['project-1'] = documentWithOneClip(revision: 1);
    final files = FakeProjectDocumentLocator({
      r'C:\projects\project-1.cmproj': documentWithOneClip(revision: 5),
    });
    await ProjectIndexRepairService(
      index: index,
      documents: files,
    ).rebuildRecent();
    expect(index.documents['project-1']!.revision, 5);
  });

  test('full rebuild removes index-only stale projects', () async {
    final index = FakeProjectIndex()
      ..documents['stale-project'] = documentWithOneClip(revision: 1);
    final files = FakeProjectDocumentLocator({
      r'C:\projects\project-1.cmproj': documentWithOneClip(revision: 5),
    });
    await ProjectIndexRepairService(
      index: index,
      documents: files,
    ).rebuildRecent();
    expect(index.documents.keys, {'project-1'});
    expect(index.documents['project-1']!.revision, 5);
  });

  test(
    'index repair warning does not hide a loaded durable document',
    () async {
      final index = FakeProjectIndex()..failUpsert = true;
      final document = documentWithOneClip(revision: 6);
      final result = await ProjectIndexRepairService(
        index: index,
        documents: FakeProjectDocumentLocator({
          r'C:\projects\project-1.cmproj': document,
        }),
      ).loadRecent();
      expect(result.documents.single, document);
      expect(result.warnings.single.code, 'project_index_upsert_failed');
    },
  );
}
