import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';

void main() {
  test('new-entity factory APIs do not accept caller-provided IDs', () {
    final factory = ProjectCommandFactory(SequenceIdGenerator(['tag-1']));
    final command = factory.createTag(name: 'Travel', color: '#123456');
    expect(command.tagId, 'tag-1');
  });

  test('factory supplies a distinct ID for every request', () {
    final factory = ProjectCommandFactory(
      SequenceIdGenerator(['tag-1', 'tag-2']),
    );
    expect(factory.createTag(name: 'One', color: '#123456').tagId, 'tag-1');
    expect(factory.createTag(name: 'Two', color: '#654321').tagId, 'tag-2');
  });

  test('provider argument maps with a new-entity ID are rejected', () {
    final factory = ProjectCommandFactory(SequenceIdGenerator(['tag-1']));
    final result = factory.fromCanonicalArguments('create_tag', {
      'tagId': 'model-supplied-id',
      'name': 'Travel',
      'color': '#123456',
    });
    expect(result, isA<Failure<ProjectCommand>>());
  });

  test('factory converts every canonical command and rejects extra fields', () {
    final factory = ProjectCommandFactory(
      SequenceIdGenerator(['right', 'text', 'image', 'tag', 'marker']),
    );
    final arguments = <String, Map<String, Object?>>{
      'trim_clip': {'clipId': 'clip-1', 'startMs': 0, 'endMs': 10},
      'remove_clip_range': {'clipId': 'clip-1', 'startMs': 1, 'endMs': 9},
      'arrange_clips': {
        'placements': [
          {'clipId': 'clip-1', 'trackId': 'track-1', 'positionMs': 0},
        ],
      },
      'set_clip_speed': {'clipId': 'clip-1', 'speed': 1.0},
      'set_clip_muted': {'clipId': 'clip-1', 'muted': true},
      'set_clip_volume': {'clipId': 'clip-1', 'volume': 1.0},
      'set_clip_transform': {
        'clipId': 'clip-1',
        'width': 1920,
        'height': 1080,
        'fit': 'contain',
        'rotationDegrees': 0,
      },
      'set_clip_brightness': {'clipId': 'clip-1', 'brightness': 0.0},
      'add_text_overlay': {
        'trackId': 'track-1',
        'startMs': 0,
        'endMs': 10,
        'text': 'Title',
        'x': 0.0,
        'y': 0.0,
      },
      'add_image_overlay': {
        'trackId': 'track-1',
        'assetId': 'asset-1',
        'startMs': 0,
        'endMs': 10,
        'x': 0.0,
        'y': 0.0,
        'width': 10,
        'height': 10,
      },
      'create_tag': {'name': 'Travel', 'color': '#112233'},
      'update_tag': {'tagId': 'tag-1', 'name': 'Travel', 'color': '#112233'},
      'delete_tag': {'tagId': 'tag-1'},
      'assign_tag': {
        'tagId': 'tag-1',
        'targetKind': 'asset',
        'targetId': 'asset-1',
      },
      'unassign_tag': {
        'tagId': 'tag-1',
        'targetKind': 'asset',
        'targetId': 'asset-1',
      },
      'create_marker': {'label': 'Beat', 'color': '#112233', 'atMs': 5},
      'update_marker': {
        'markerId': 'marker-1',
        'label': 'Beat',
        'color': '#112233',
        'atMs': 5,
      },
      'delete_marker': {'markerId': 'marker-1'},
    };
    final converted = arguments.entries.map((entry) {
      final result = factory.fromCanonicalArguments(entry.key, entry.value);
      return (result as Success<ProjectCommand>).value.type;
    }).toSet();
    expect(converted, arguments.keys.toSet());
    expect(
      factory.fromCanonicalArguments('set_clip_volume', {
        'clipId': 'clip-1',
        'volume': 1.0,
        'extra': true,
      }),
      isA<Failure<ProjectCommand>>(),
    );
  });
}
