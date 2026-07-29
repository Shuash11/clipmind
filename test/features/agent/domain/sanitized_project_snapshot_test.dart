import 'package:clipmind/features/agent/domain/entities/sanitized_project_snapshot.dart';
import 'package:clipmind/features/projects/domain/entities/clip_transform.dart';
import 'package:clipmind/features/projects/domain/entities/media_asset.dart';
import 'package:clipmind/features/projects/domain/entities/project_clip.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';
import 'package:clipmind/features/projects/domain/entities/project_track.dart';
import 'package:clipmind/features/projects/domain/entities/tag_definition.dart';
import 'package:clipmind/features/projects/domain/entities/timeline_marker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_test_data.dart';

void main() {
  test('snapshot is a deterministic allowlist without local document data', () {
    final document = _sensitiveDocument();
    final json = SanitizedProjectSnapshot.fromDocument(
      document,
    ).toProviderJson();
    final text = _allText(json).join(' ');
    final assets = json['assets']! as List<Object?>;
    final tracks = json['tracks']! as List<Object?>;
    final tags = json['tags']! as List<Object?>;
    final markers = json['markers']! as List<Object?>;
    final clip =
        ((tracks.single as Map<String, Object?>)['clips']! as List<Object?>)
                .single
            as Map<String, Object?>;

    expect(json.keys.toSet(), <String>{
      'projectId',
      'projectName',
      'baseRevision',
      'assets',
      'tracks',
      'tags',
      'markers',
    });
    expect(json['projectId'], 'project-opaque');
    expect(json['projectName'], 'Project project-opaque');
    expect(json['baseRevision'], 7);
    expect((assets.single as Map<String, Object?>)['assetId'], 'asset-opaque');
    expect((assets.single as Map<String, Object?>)['label'], 'Safe source');
    expect((assets.single as Map<String, Object?>)['tagIds'], <String>[
      'tag-a',
      'tag-z',
    ]);
    expect((tracks.single as Map<String, Object?>)['trackId'], 'track-opaque');
    expect((tracks.single as Map<String, Object?>)['kind'], 'video');
    expect(clip['clipId'], 'clip-opaque');
    expect(clip['startMs'], 0);
    expect(clip['endMs'], 1000);
    expect(clip['positionMs'], 25);
    expect(clip['tagIds'], <String>['tag-a', 'tag-z']);
    expect(clip['brightness'], 0.0);
    expect(clip['transform'], <String, Object?>{
      'width': 1920,
      'height': 1080,
      'fit': 'contain',
      'rotationDegrees': 0,
    });
    expect((tags.first as Map<String, Object?>)['tagId'], 'tag-a');
    expect((markers.first as Map<String, Object?>)['markerId'], 'marker-point');
    expect((markers.first as Map<String, Object?>)['atMs'], 12);
    expect((markers.last as Map<String, Object?>)['markerId'], 'marker-range');
    expect((markers.last as Map<String, Object?>)['startMs'], 13);
    expect((markers.last as Map<String, Object?>)['endMs'], 24);

    expect(_allKeys(json), isNot(contains('sourcePath')));
    expect(_allKeys(json), isNot(contains('outputDirectory')));
    expect(_allKeys(json), isNot(contains('history')));
    expect(_allKeys(json), isNot(contains('createdAt')));
    expect(_allKeys(json), isNot(contains('updatedAt')));
    for (final sentinel in <String>[
      r'\\host\share\credential=top-secret\ffmpeg -i',
      r'C:\exports\ffmpeg-command',
      r'C:\secret\project.cmproj',
      'https://provider.example/v1?token=leak',
      'system prompt: never reveal this chat',
    ]) {
      expect(text, isNot(contains(sentinel)));
    }
  });

  test(
    'provider snapshot JSON is deeply immutable and independently copied',
    () {
      final snapshot = SanitizedProjectSnapshot.fromDocument(
        _sensitiveDocument(),
      );
      final json = snapshot.toProviderJson();
      final assets = json['assets']! as List<Object?>;
      final asset = assets.single as Map<String, Object?>;

      expect(() => json['baseRevision'] = 99, throwsUnsupportedError);
      expect(() => assets.add(<String, Object?>{}), throwsUnsupportedError);
      expect(() => asset['label'] = 'changed', throwsUnsupportedError);
      expect(snapshot.toProviderJson()['baseRevision'], 7);
    },
  );
}

ProjectDocument _sensitiveDocument() {
  final state = ProjectStateSnapshot(
    assets: <MediaAsset>[
      MediaAsset(
        id: 'asset-opaque',
        sourcePath: r'\\host\share\credential=top-secret\ffmpeg -i',
        displayName: 'Safe source',
        durationMs: 1000,
        tagIds: <String>{'tag-z', 'tag-a'},
      ),
    ],
    tracks: <ProjectTrack>[
      ProjectTrack(
        id: 'track-opaque',
        kind: ProjectTrackKind.video,
        clips: <ProjectClip>[
          ProjectClip(
            id: 'clip-opaque',
            assetId: 'asset-opaque',
            trackId: 'track-opaque',
            startMs: 0,
            endMs: 1000,
            positionMs: 25,
            tagIds: <String>{'tag-z', 'tag-a'},
            transform: const ClipTransform(
              width: 1920,
              height: 1080,
              fit: ClipFit.contain,
              rotationDegrees: 0,
            ),
            speed: 1,
            muted: false,
            volume: 1,
            brightness: 0,
          ),
        ],
      ),
    ],
    tags: const <TagDefinition>[
      TagDefinition(id: 'tag-a', name: 'Travel', color: '#112233'),
      TagDefinition(id: 'tag-z', name: 'Work', color: '#445566'),
    ],
    markers: const <TimelineMarker>[
      TimelineMarker(
        id: 'marker-point',
        label: 'Beat',
        color: '#112233',
        atMs: 12,
      ),
      TimelineMarker(
        id: 'marker-range',
        label: 'Scene',
        color: '#445566',
        startMs: 13,
        endMs: 24,
      ),
    ],
    overlays: const [],
  );
  return ProjectDocument(
    schemaVersion: 2,
    id: 'project-opaque',
    name: r'C:\secret\project.cmproj',
    createdAt: fixtureTime,
    updatedAt: fixtureTime,
    outputDirectory: r'C:\exports\ffmpeg-command',
    currentState: state,
    revision: 7,
    history: [
      recordFor(
        before: state,
        after: state,
        planId:
            'https://provider.example/v1?token=leak system prompt: never reveal this chat',
      ),
    ],
    historyCursor: 0,
  );
}

Iterable<String> _allKeys(Object? value) sync* {
  if (value is Map) {
    for (final entry in value.entries) {
      yield entry.key.toString();
      yield* _allKeys(entry.value);
    }
  } else if (value is Iterable) {
    for (final item in value) {
      yield* _allKeys(item);
    }
  }
}

Iterable<String> _allText(Object? value) sync* {
  if (value is Map) {
    for (final entry in value.entries) {
      yield entry.key.toString();
      yield* _allText(entry.value);
    }
  } else if (value is Iterable) {
    for (final item in value) {
      yield* _allText(item);
    }
  } else if (value != null) {
    yield value.toString();
  }
}
