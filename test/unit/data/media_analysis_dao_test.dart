import 'package:clipmind/data/local/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('MediaAnalysis DAO (schema v4)', () {
    test('schema exposes the media_analysis table', () async {
      final columns = await db
          .customSelect('PRAGMA table_info(media_analysis)')
          .get();
      final names = columns
          .map((row) => row.read<String>('name'))
          .toSet();
      expect(
        names,
        containsAll([
          'id',
          'project_id',
          'kind',
          'source_path',
          'payload',
          'created_at',
        ]),
      );
    });

    test('save + get round-trips the payload', () async {
      await db.saveAnalysis(
        projectId: 'p1',
        kind: 'scenes:clip_1',
        sourcePath: '/v/a.mp4',
        payload: const {
          'clip_id': 'clip_1',
          'source_path': '/v/a.mp4',
          'scenes_ms': [0, 1000],
          'count': 2,
        },
      );

      final row = await db.getAnalysis('p1', 'scenes:clip_1');
      expect(row, isNotNull);
      expect(row!.id, equals('p1:scenes:clip_1'));
      expect(row.projectId, equals('p1'));
      expect(row.kind, equals('scenes:clip_1'));
      expect(row.sourcePath, equals('/v/a.mp4'));

      final payload = await db.getAnalysisPayload('p1', 'scenes:clip_1');
      expect(payload, isNotNull);
      expect(payload!['count'], equals(2));
      expect(payload['scenes_ms'], equals([0, 1000]));
    });

    test('save overwrites (upsert) without duplicating rows', () async {
      await db.saveAnalysis(
        projectId: 'p1',
        kind: 'scenes:clip_1',
        sourcePath: '/v/a.mp4',
        payload: const {'count': 1},
      );
      await db.saveAnalysis(
        projectId: 'p1',
        kind: 'scenes:clip_1',
        sourcePath: '/v/a.mp4',
        payload: const {'count': 2},
      );
      final payload = await db.getAnalysisPayload('p1', 'scenes:clip_1');
      expect(payload!['count'], equals(2));
    });

    test('kinds are independent per clip', () async {
      await db.saveAnalysis(
        projectId: 'p1',
        kind: 'scenes:clip_1',
        sourcePath: '/v/a.mp4',
        payload: const {'count': 1},
      );
      await db.saveAnalysis(
        projectId: 'p1',
        kind: 'transcript:clip_1',
        sourcePath: '/v/a.mp4',
        payload: const {'text': 'hello'},
      );
      expect(
        (await db.getAnalysisPayload('p1', 'scenes:clip_1'))!['count'],
        equals(1),
      );
      expect(
        (await db.getAnalysisPayload('p1', 'transcript:clip_1'))!['text'],
        equals('hello'),
      );
    });

    test('missing row and corrupt payload yield null', () async {
      expect(await db.getAnalysis('p1', 'scenes:ghost'), isNull);
      expect(
        await db.getAnalysisPayload('p1', 'scenes:ghost'),
        isNull,
      );
      await db
          .into(db.mediaAnalysis)
          .insertOnConflictUpdate(
            const MediaAnalysisRow(
              id: 'p1:scenes:bad',
              projectId: 'p1',
              kind: 'scenes:bad',
              sourcePath: '/v/a.mp4',
              payload: '{not json',
              createdAt: 0,
            ),
          );
      expect(
        await db.getAnalysisPayload('p1', 'scenes:bad'),
        isNull,
      );
    });

    test('deleteAnalysis clears one project only', () async {
      await db.saveAnalysis(
        projectId: 'p1',
        kind: 'scenes:clip_1',
        sourcePath: '/v/a.mp4',
        payload: const {'count': 1},
      );
      await db.saveAnalysis(
        projectId: 'p2',
        kind: 'scenes:clip_1',
        sourcePath: '/v/a.mp4',
        payload: const {'count': 1},
      );
      await db.deleteAnalysis('p1');
      expect(await db.getAnalysis('p1', 'scenes:clip_1'), isNull);
      expect(await db.getAnalysis('p2', 'scenes:clip_1'), isNotNull);
    });
  });
}
