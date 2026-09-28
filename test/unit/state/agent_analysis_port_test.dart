import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/state/agent_analysis_providers.dart';
import 'package:clipmind/state/settings_providers.dart';

void main() {
  group('AgentAnalysisPort', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('warmUp loads cached payloads for clip kinds', () async {
      await db.saveAnalysis(
        projectId: 'p1',
        kind: 'scenes:clip_1',
        sourcePath: '/v/in.mp4',
        payload: const {
          'source_path': '/v/in.mp4',
          'scenes': [1, 2],
        },
      );
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final port = container.read(agentAnalysisPortProvider('p1'));
      expect(port.read('scenes:clip_1'), isNull);
      await port.warmUp(['clip_1', 'clip_2']);

      expect(port.read('scenes:clip_1'), isNotNull);
      expect(port.read('scenes:clip_1')!['scenes'], equals([1, 2]));
      expect(port.read('scenes:clip_2'), isNull);
      expect(port.read('transcript:clip_1'), isNull);
    });

    test('write caches immediately and persists best-effort', () async {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final port = container.read(agentAnalysisPortProvider('p1'));
      port.write('transcript:clip_9', const {
        'source_path': '/v/other.mp4',
        'text': 'hello',
      });
      expect(port.read('transcript:clip_9')!['text'], equals('hello'));

      for (var i = 0; i < 200; i++) {
        final stored = await db.getAnalysisPayload('p1', 'transcript:clip_9');
        if (stored != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final stored = await db.getAnalysisPayload('p1', 'transcript:clip_9');
      expect(stored, isNotNull);
      expect(stored!['text'], equals('hello'));
    });

    test('provider is scoped per project id', () {
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      expect(
        identical(
          container.read(agentAnalysisPortProvider('p1')),
          container.read(agentAnalysisPortProvider('p1')),
        ),
        isTrue,
      );
      expect(
        identical(
          container.read(agentAnalysisPortProvider('p1')),
          container.read(agentAnalysisPortProvider('p2')),
        ),
        isFalse,
      );
    });
  });
}
