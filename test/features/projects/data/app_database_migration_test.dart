import 'package:clipmind/data/local/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import '../support/legacy_v1_database.dart';

void main() {
  test(
    'v1 to v2 hub-index migration preserves rows and adds rebuildable metadata only',
    () async {
      final fixture = await legacyV1ProjectIndexFixture();
      final database = AppDatabase(fixture.executor);

      try {
        final migrated = await database
            .customSelect(
              'SELECT id, name, project_path, document_schema_version, '
              'document_revision FROM projects WHERE id = ?',
              variables: [const Variable<String>('project-1')],
            )
            .getSingle();
        expect(migrated.read<String>('id'), 'project-1');
        expect(migrated.read<String>('name'), 'Existing');
        expect(
          migrated.read<String>('project_path'),
          r'C:\projects\project-1.cmproj',
        );
        expect(migrated.read<int?>('document_schema_version'), isNull);
        expect(migrated.read<int?>('document_revision'), isNull);
        final columns = await database
            .customSelect('PRAGMA table_info(projects)')
            .get();
        final names = columns
            .map((QueryRow column) => column.read<String>('name'))
            .toSet();
        expect(
          names,
          containsAll([
            'id',
            'project_path',
            'document_schema_version',
            'document_revision',
          ]),
        );
        expect(names, isNot(contains('project_document_json')));
      } finally {
        await database.close();
        await fixture.dispose();
      }
    },
  );
}
