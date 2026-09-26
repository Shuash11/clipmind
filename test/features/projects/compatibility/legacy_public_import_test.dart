import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'deprecated public models remain decode-compatible during project transition',
    () {
      final project = Project.fromJson({
        'id': 'legacy-project',
        'name': 'Legacy',
        'createdAt': '2026-07-01T00:00:00.000Z',
        'updatedAt': '2026-07-01T00:00:00.000Z',
        'sourceMediaPaths': [r'C:\media\legacy.mp4'],
        'tracks': [
          {
            'id': 'track-1',
            'type': 'video',
            'clips': [
              {
                'id': 'clip-1',
                'trackId': 'track-1',
                'sourcePath': r'C:\media\legacy.mp4',
                'startMs': 0,
                'endMs': 100,
              },
            ],
          },
        ],
      });
      expect(project, isA<Project>());
      expect(project.tracks.single, isA<Track>());
      expect(project.tracks.single.clips.single, isA<Clip>());
      expect(
        project.tracks.single.clips.single.sourcePath,
        r'C:\media\legacy.mp4',
      );
    },
  );
}
