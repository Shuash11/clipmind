import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/state/project_providers.dart';

Project _project() {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['/v/a.mp4', '/v/b.mp4'],
    tracks: const [
      Track(
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
          ),
          Clip(
            id: 'clip_2',
            trackId: 't1',
            sourcePath: '/v/b.mp4',
            startMs: 0,
            endMs: 30000,
          ),
        ],
      ),
      Track(
        id: 't2',
        type: TrackType.audio,
        label: 'Audio',
        clips: [
          Clip(
            id: 'clip_3',
            trackId: 't2',
            sourcePath: '/v/a.mp4',
            startMs: 0,
            endMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: 90000,
    outputDir: '/out',
  );
}

EditOperation _op(List<String> targets) => EditOperation(
      id: 'op_1',
      type: EditOperationType.merge,
      targetClipIds: targets,
      createdAt: DateTime(2026, 1, 2),
    );

void main() {
  group('ProjectNotifier.applyEdit', () {
    test('removeClipIds drops clips, repoints first, appends history',
        () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(_project());

      container.read(projectProvider.notifier).applyEdit(
            _op(const ['clip_1']),
            '/out/merged.mp4',
            removeClipIds: const ['clip_2'],
          );

      final updated = container.read(projectProvider).value!;
      final video =
          updated.tracks.firstWhere((t) => t.id == 't1').clips;
      expect(video.map((c) => c.id), equals(['clip_1']));
      expect(video.single.sourcePath, equals('/out/merged.mp4'));
      // Untouched track keeps its clip.
      expect(
        updated.tracks.firstWhere((t) => t.id == 't2').clips.single.id,
        equals('clip_3'),
      );
      expect(updated.editHistory.map((e) => e.id), equals(['op_1']));
    });

    test('empty default repoints only, removes nothing', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      container.read(projectProvider.notifier).setProject(_project());

      container.read(projectProvider.notifier).applyEdit(
            _op(const ['clip_1']),
            '/out/trimmed.mp4',
          );

      final updated = container.read(projectProvider).value!;
      expect(
        updated.tracks
            .expand((t) => t.clips)
            .map((c) => c.id)
            .toList(),
        equals(['clip_1', 'clip_2', 'clip_3']),
      );
      expect(
        updated.tracks
            .expand((t) => t.clips)
            .firstWhere((c) => c.id == 'clip_1')
            .sourcePath,
        equals('/out/trimmed.mp4'),
      );
      expect(updated.editHistory, hasLength(1));
    });
  });
}
