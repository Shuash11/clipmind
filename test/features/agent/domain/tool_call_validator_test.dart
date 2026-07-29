import 'package:clipmind/features/agent/domain/entities/tool_call.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/features/agent/domain/services/tool_call_validator.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/entities/timeline_marker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  test(
    'validates brightness including zero and creates only a local payload',
    () {
      final validator = ToolCallValidator(
        registry: EditorToolRegistry.standard(),
        commandFactory: ProjectCommandFactory(SequenceIdGenerator([])),
        commandExecutor: ProjectCommandExecutor.standard(),
      );
      final result = validator.validate([
        ToolCall(
          callId: 'call-1',
          name: 'set_clip_brightness',
          arguments: {'clipId': 'clip-1', 'brightness': 0},
        ),
      ], documentWithOneClip());

      expect(result.isValid, isTrue);
      expect(result.payload, isNotNull);
      expect(result.candidate, isNotNull);
    },
  );

  test('rejects duplicate IDs without commands', () {
    final validator = ToolCallValidator(
      registry: EditorToolRegistry.standard(),
      commandFactory: ProjectCommandFactory(SequenceIdGenerator([])),
      commandExecutor: ProjectCommandExecutor.standard(),
    );
    final calls = [
      ToolCall(
        callId: 'same',
        name: 'set_clip_speed',
        arguments: {'clipId': 'clip-1', 'speed': 1},
      ),
      ToolCall(
        callId: 'same',
        name: 'set_clip_brightness',
        arguments: {'clipId': 'clip-1', 'brightness': -1},
      ),
    ];
    final result = validator.validate(calls, documentWithOneClip());
    expect(result.commands, isEmpty);
    expect(result.findings.first.code, 'duplicate_call_id');
  });

  test(
    'interior removal receives a factory ID and preserves clip settings',
    () {
      final validator = ToolCallValidator(
        registry: EditorToolRegistry.standard(),
        commandFactory: ProjectCommandFactory(
          SequenceIdGenerator(['right-clip']),
        ),
        commandExecutor: ProjectCommandExecutor.standard(),
      );
      final result = validator.validate([
        ToolCall(
          callId: 'range',
          name: 'remove_clip_range',
          arguments: {'clipId': 'clip-1', 'startMs': 100, 'endMs': 200},
        ),
      ], documentWithOneClip());
      final clips = result.candidate!.tracks.single.clips;
      expect(clips.map((clip) => clip.id), contains('right-clip'));
      expect(clips.every((clip) => clip.assetId == 'asset-1'), isTrue);
      expect(clips.every((clip) => clip.tagIds.contains('tag-1')), isTrue);
      expect(clips[0].positionMs, 0);
      expect(clips[1].positionMs, 100);
      for (final clip in clips) {
        expect(clip.transform.width, 1920);
        expect(clip.speed, 1);
        expect(clip.muted, isFalse);
        expect(clip.volume, 1);
        expect(clip.brightness, 0);
      }
    },
  );

  test('every canonical tool has a successful current-document path', () {
    final base = documentWithOneClip();
    final markerDocument = documentWithOneClip(
      state: stateWithOneClip().copyWith(
        markers: [
          const TimelineMarker(
            id: 'marker-1',
            label: 'Old',
            color: '#112233',
            atMs: 10,
          ),
        ],
      ),
    );
    final untagged = documentWithOneClip(
      state: stateWithOneClip().copyWith(
        assets: [stateWithOneClip().assets.single.copyWith(tagIds: {})],
      ),
    );
    final cases = <(String, Map<String, Object?>, dynamic)>[
      ('trim_clip', {'clipId': 'clip-1', 'startMs': 0, 'endMs': 900}, base),
      (
        'remove_clip_range',
        {'clipId': 'clip-1', 'startMs': 100, 'endMs': 200},
        base,
      ),
      (
        'arrange_clips',
        {
          'placements': [
            {'clipId': 'clip-1', 'trackId': 'track-1', 'positionMs': 1},
          ],
        },
        base,
      ),
      ('set_clip_speed', {'clipId': 'clip-1', 'speed': .25}, base),
      ('set_clip_muted', {'clipId': 'clip-1', 'muted': true}, base),
      ('set_clip_volume', {'clipId': 'clip-1', 'volume': 0}, base),
      (
        'set_clip_transform',
        {
          'clipId': 'clip-1',
          'width': 16,
          'height': 16,
          'fit': 'cover',
          'rotationDegrees': 1,
        },
        base,
      ),
      ('set_clip_brightness', {'clipId': 'clip-1', 'brightness': -1}, base),
      (
        'add_text_overlay',
        {
          'trackId': 'track-1',
          'startMs': 0,
          'endMs': 1,
          'text': 'T',
          'x': 0,
          'y': 0,
        },
        base,
      ),
      (
        'add_image_overlay',
        {
          'trackId': 'track-1',
          'assetId': 'asset-1',
          'startMs': 0,
          'endMs': 1,
          'x': 0,
          'y': 0,
          'width': 1,
          'height': 1,
        },
        base,
      ),
      ('create_tag', {'name': 'Work', 'color': '#abcdef'}, base),
      (
        'update_tag',
        {'tagId': 'tag-1', 'name': 'Holiday', 'color': '#abcdef'},
        base,
      ),
      ('delete_tag', {'tagId': 'tag-1'}, base),
      (
        'assign_tag',
        {'tagId': 'tag-1', 'targetKind': 'asset', 'targetId': 'asset-1'},
        untagged,
      ),
      (
        'unassign_tag',
        {'tagId': 'tag-1', 'targetKind': 'asset', 'targetId': 'asset-1'},
        base,
      ),
      ('create_marker', {'label': 'Beat', 'color': '#abcdef', 'atMs': 1}, base),
      (
        'update_marker',
        {
          'markerId': 'marker-1',
          'label': 'Beat',
          'color': '#abcdef',
          'atMs': 1,
        },
        markerDocument,
      ),
      ('delete_marker', {'markerId': 'marker-1'}, markerDocument),
    ];
    for (var index = 0; index < cases.length; index++) {
      final item = cases[index];
      final validator = ToolCallValidator(
        registry: EditorToolRegistry.standard(),
        commandFactory: ProjectCommandFactory(
          SequenceIdGenerator(['new-$index', 'extra-$index']),
        ),
        commandExecutor: ProjectCommandExecutor.standard(),
      );
      final result = validator.validate([
        ToolCall(callId: 'call-$index', name: item.$1, arguments: item.$2),
      ], item.$3);
      expect(result.isValid, isTrue, reason: item.$1);
    }
  });

  test('schema, bounds, target, and conflict rejections are atomic', () {
    final validator = ToolCallValidator(
      registry: EditorToolRegistry.standard(),
      commandFactory: ProjectCommandFactory(
        SequenceIdGenerator(['unconsumed']),
      ),
      commandExecutor: ProjectCommandExecutor.standard(),
    );
    final cases = <ToolCall>[
      ToolCall(
        callId: 'missing',
        name: 'set_clip_speed',
        arguments: {'clipId': 'clip-1'},
      ),
      ToolCall(
        callId: 'extra',
        name: 'set_clip_speed',
        arguments: {'clipId': 'clip-1', 'speed': 1, 'extra': true},
      ),
      ToolCall(
        callId: 'wrong',
        name: 'set_clip_speed',
        arguments: {'clipId': 'clip-1', 'speed': 'fast'},
      ),
      ToolCall(
        callId: 'range',
        name: 'set_clip_brightness',
        arguments: {'clipId': 'clip-1', 'brightness': 2},
      ),
      ToolCall(
        callId: 'enum',
        name: 'set_clip_transform',
        arguments: {
          'clipId': 'clip-1',
          'width': 16,
          'height': 16,
          'fit': 'bad',
          'rotationDegrees': 0,
        },
      ),
      ToolCall(
        callId: 'clip',
        name: 'set_clip_speed',
        arguments: {'clipId': 'unknown', 'speed': 1},
      ),
      ToolCall(
        callId: 'track',
        name: 'add_text_overlay',
        arguments: {
          'trackId': 'unknown',
          'startMs': 0,
          'endMs': 1,
          'text': 'x',
          'x': 0,
          'y': 0,
        },
      ),
      ToolCall(
        callId: 'asset',
        name: 'add_image_overlay',
        arguments: {
          'trackId': 'track-1',
          'assetId': 'unknown',
          'startMs': 0,
          'endMs': 1,
          'x': 0,
          'y': 0,
          'width': 1,
          'height': 1,
        },
      ),
      ToolCall(
        callId: 'trim',
        name: 'trim_clip',
        arguments: {'clipId': 'clip-1', 'startMs': 1, 'endMs': 1001},
      ),
      ToolCall(
        callId: 'marker',
        name: 'create_marker',
        arguments: {
          'label': 'x',
          'color': '#abcdef',
          'atMs': 1,
          'startMs': 0,
          'endMs': 2,
        },
      ),
    ];
    for (final call in cases) {
      final result = validator.validate([call], documentWithOneClip());
      expect(result.commands, isEmpty, reason: call.callId);
      expect(result.payload, isNull);
      expect(result.candidate, isNull);
      expect(result.findings, isNotEmpty);
    }
  });

  test(
    'independent clip changes are allowed while exclusive edits conflict',
    () {
      ToolCall call(String id, String name, Map<String, Object?> args) =>
          ToolCall(callId: id, name: name, arguments: args);
      final valid =
          ToolCallValidator(
            registry: EditorToolRegistry.standard(),
            commandFactory: ProjectCommandFactory(SequenceIdGenerator([])),
            commandExecutor: ProjectCommandExecutor.standard(),
          ).validate([
            call('speed', 'set_clip_speed', {'clipId': 'clip-1', 'speed': 2}),
            call('bright', 'set_clip_brightness', {
              'clipId': 'clip-1',
              'brightness': 0,
            }),
          ], documentWithOneClip());
      expect(valid.isValid, isTrue);
      final conflict =
          ToolCallValidator(
            registry: EditorToolRegistry.standard(),
            commandFactory: ProjectCommandFactory(
              SequenceIdGenerator(['unused']),
            ),
            commandExecutor: ProjectCommandExecutor.standard(),
          ).validate([
            call('trim', 'trim_clip', {
              'clipId': 'clip-1',
              'startMs': 0,
              'endMs': 900,
            }),
            call('cut', 'remove_clip_range', {
              'clipId': 'clip-1',
              'startMs': 100,
              'endMs': 200,
            }),
          ], documentWithOneClip());
      expect(conflict.commands, isEmpty);
      expect(
        conflict.findings.any((finding) => finding.code == 'conflicting_calls'),
        isTrue,
      );
    },
  );
}
