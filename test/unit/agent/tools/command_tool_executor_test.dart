import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/domain/agent/agent_edit_applier.dart';
import 'package:clipmind/domain/agent/tools/tool_definition.dart';
import 'package:clipmind/domain/agent/tools/tool_executors.dart';
import 'package:clipmind/features/projects/domain/commands/marker_commands.dart';
import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';
import 'package:clipmind/features/projects/domain/entities/timeline_marker.dart';

import '../../../features/projects/support/project_fakes.dart';
import '../../../features/projects/support/project_test_data.dart';
import 'support/fake_project_command_gateway.dart';

Project _project() => Project(
  id: 'p1',
  name: 'Test',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  sourceMediaPaths: const [r'C:\v\input.mp4'],
  tracks: const [
    Track(
      id: 't1',
      type: TrackType.video,
      label: 'Video',
      clips: [
        Clip(
          id: 'clip-1',
          trackId: 't1',
          sourcePath: r'C:\v\input.mp4',
          startMs: 0,
          endMs: 60000,
        ),
      ],
    ),
  ],
  durationMs: 60000,
  outputDir: r'C:\out',
);

ToolExecutionContext _ctx({
  FakeProjectCommandGateway? gateway,
  bool dryRun = false,
  List<String> ids = const ['gen-1', 'gen-2', 'gen-3'],
}) => ToolExecutionContext(
  project: _project,
  outputDir: r'C:\out',
  projectDir: r'C:\out',
  applier: AgentEditApplier(
    onApply: (_, _, {removeClipIds = const []}) async {},
  ),
  ffmpegService: FfmpegService(),
  ffprobeService: FfprobeService(),
  gateway: gateway,
  commandIdGenerator: SequenceIdGenerator(ids),
  dryRun: dryRun,
);

/// The fixture assigns `tag-1` to the asset; this variant clears it.
ProjectStateSnapshot _stateWithFreeAsset() {
  final base = stateWithOneClip();
  return base.copyWith(
    assets: [base.assets.single.copyWith(tagIds: const <String>{})],
  );
}

void main() {
  group('CommandToolExecutor', () {
    test('create_tag builds a command and applies it through the gateway',
        () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final executor = CommandToolExecutor(
        _ctx(gateway: gateway, ids: const ['tag-new']),
      );

      final result = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'create_tag',
        args: {'name': 'Music', 'color': '#AABBCC'},
      ));

      expect(result.success, isTrue);
      final command = gateway.appliedCommands.single as CreateTagCommand;
      expect(command.tagId, 'tag-new');
      expect(command.name, 'Music');
      expect(command.color, '#AABBCC');
      expect(result.data['command_type'], 'create_tag');
      expect(result.data['target_ids'], ['tag-new']);
      // Canonical summary drives the step summary.
      expect(result.summary, contains('Created tag'));
      expect(result.summary, contains('tag-new'));
      expect(gateway.state!.tags.last.name, 'Music');
    });

    test('handler validation text surfaces with an actionable hint', () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final executor = CommandToolExecutor(_ctx(gateway: gateway));

      // Duplicate name (case-insensitive) is rejected by the tag handler.
      final result = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'create_tag',
        args: {'name': 'travel', 'color': '#112233'},
      ));

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid tag'));
      expect(result.error, contains('#RRGGBB'));
      expect(result.error, contains('list_tags_and_markers'));
      // The attempt still went through the pipeline (single mutation path).
      expect(gateway.batches, hasLength(1));
    });

    test('update_tag renames and recolors; unknown IDs fail', () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final executor = CommandToolExecutor(_ctx(gateway: gateway));

      final result = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'update_tag',
        args: {'tag_id': 'tag-1', 'name': 'Journey', 'color': '#334455'},
      ));

      expect(result.success, isTrue);
      final command = gateway.appliedCommands.single as UpdateTagCommand;
      expect(command.tagId, 'tag-1');
      expect(gateway.state!.tags.single.name, 'Journey');
      expect(gateway.state!.tags.single.color, '#334455');

      final missing = await executor.execute(const ToolCall(
        id: 'c2',
        name: 'update_tag',
        args: {'tag_id': 'ghost', 'name': 'Journey', 'color': '#334455'},
      ));
      expect(missing.success, isFalse);
      expect(missing.error, contains('Invalid tag update'));
    });

    test('delete_tag removes the tag and its target associations', () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final executor = CommandToolExecutor(_ctx(gateway: gateway));

      final result = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'delete_tag',
        args: {'tag_id': 'tag-1'},
      ));

      expect(result.success, isTrue);
      expect(gateway.state!.tags, isEmpty);
      expect(gateway.state!.assets.single.tagIds, isEmpty);
      expect(gateway.state!.tracks.single.clips.single.tagIds, isEmpty);
    });

    test('assign_tag maps target_kind/target_id; invalid kind never calls',
        () async {
      final gateway = FakeProjectCommandGateway(state: _stateWithFreeAsset());
      final executor = CommandToolExecutor(_ctx(gateway: gateway));

      final result = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'assign_tag',
        args: {'tag_id': 'tag-1', 'target_kind': 'asset', 'target_id': 'asset-1'},
      ));

      expect(result.success, isTrue);
      final command = gateway.appliedCommands.single as AssignTagCommand;
      expect(command.targetKind, AssignmentTargetKind.asset);
      expect(command.targetId, 'asset-1');
      expect(gateway.state!.assets.single.tagIds, contains('tag-1'));

      final invalid = await executor.execute(const ToolCall(
        id: 'c2',
        name: 'assign_tag',
        args: {'tag_id': 'tag-1', 'target_kind': 'timeline', 'target_id': 'asset-1'},
      ));
      expect(invalid.success, isFalse);
      expect(invalid.error, contains('target_kind'));
      expect(gateway.batches, hasLength(1));
    });

    test('unassign_tag detaches from a clip; no-op assignment fails', () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final executor = CommandToolExecutor(_ctx(gateway: gateway));

      final result = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'unassign_tag',
        args: {'tag_id': 'tag-1', 'target_kind': 'clip', 'target_id': 'clip-1'},
      ));

      expect(result.success, isTrue);
      final command = gateway.appliedCommands.single as UnassignTagCommand;
      expect(command.targetKind, AssignmentTargetKind.clip);
      expect(gateway.state!.tracks.single.clips.single.tagIds, isEmpty);

      // Unassigning again is a no-op rejected by the handler.
      final noop = await executor.execute(const ToolCall(
        id: 'c2',
        name: 'unassign_tag',
        args: {'tag_id': 'tag-1', 'target_kind': 'clip', 'target_id': 'clip-1'},
      ));
      expect(noop.success, isFalse);
      expect(noop.error, contains('Invalid tag assignment'));
    });

    test('create_marker builds point and range commands; XOR is enforced',
        () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final executor = CommandToolExecutor(
        _ctx(
          gateway: gateway,
          ids: const ['m-point', 'm-range', 'm-empty', 'm-both'],
        ),
      );

      final point = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'create_marker',
        args: {
          'label': 'Intro',
          'color': '#FF0000',
          'at_ms': 1200,
          'start_ms': null,
          'end_ms': null,
        },
      ));
      expect(point.success, isTrue);
      final pointCommand = gateway.appliedCommands.first as CreateMarkerCommand;
      expect(pointCommand.markerId, 'm-point');
      expect(pointCommand.atMs, 1200);
      expect(pointCommand.startMs, isNull);

      final range = await executor.execute(const ToolCall(
        id: 'c2',
        name: 'create_marker',
        args: {
          'label': 'Chapter',
          'color': '#00FF00',
          'at_ms': null,
          'start_ms': 100,
          'end_ms': 900,
        },
      ));
      expect(range.success, isTrue);
      final rangeCommand = gateway.appliedCommands.last as CreateMarkerCommand;
      expect(rangeCommand.atMs, isNull);
      expect(rangeCommand.startMs, 100);
      expect(rangeCommand.endMs, 900);

      // Neither point nor range: the marker handler rejects it.
      final empty = await executor.execute(const ToolCall(
        id: 'c3',
        name: 'create_marker',
        args: {
          'label': 'Nope',
          'color': '#000000',
          'at_ms': null,
          'start_ms': null,
          'end_ms': null,
        },
      ));
      expect(empty.success, isFalse);
      expect(empty.error, contains('Invalid marker'));
      expect(empty.error, contains('at_ms'));

      // Both point and range: also rejected (handler XOR rule).
      final both = await executor.execute(const ToolCall(
        id: 'c4',
        name: 'create_marker',
        args: {
          'label': 'Both',
          'color': '#000000',
          'at_ms': 10,
          'start_ms': 1,
          'end_ms': 2,
        },
      ));
      expect(both.success, isFalse);
      expect(both.error, contains('Invalid marker'));
    });

    test('update_marker rewrites label/color/position', () async {
      final gateway = FakeProjectCommandGateway(
        state: stateWithOneClip().copyWith(
          markers: const [
            TimelineMarker(
              id: 'marker-1',
              label: 'Intro',
              color: '#FF0000',
              atMs: 500,
            ),
          ],
        ),
      );
      final executor = CommandToolExecutor(_ctx(gateway: gateway));

      final result = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'update_marker',
        args: {
          'marker_id': 'marker-1',
          'label': 'Intro 2',
          'color': '#0000FF',
          'at_ms': 900,
          'start_ms': null,
          'end_ms': null,
        },
      ));

      expect(result.success, isTrue);
      final command = gateway.appliedCommands.single as UpdateMarkerCommand;
      expect(command.markerId, 'marker-1');
      expect(gateway.state!.markers.single.label, 'Intro 2');
      expect(gateway.state!.markers.single.atMs, 900);
    });

    test('delete_marker surfaces handler text for unknown IDs', () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final executor = CommandToolExecutor(_ctx(gateway: gateway));

      final result = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'delete_marker',
        args: {'marker_id': 'ghost'},
      ));

      expect(result.success, isFalse);
      expect(result.error, contains('Unknown marker'));
      expect(result.error, contains('list_tags_and_markers'));
    });

    test('dry run returns planned without touching the gateway', () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final executor = CommandToolExecutor(
        _ctx(gateway: gateway, dryRun: true, ids: const ['tag-new']),
      );

      final result = await executor.execute(const ToolCall(
        id: 'c1',
        name: 'create_tag',
        args: {'name': 'Music', 'color': '#AABBCC'},
      ));

      expect(result.success, isTrue);
      expect(result.data['planned'], isTrue);
      expect(result.data['command_type'], 'create_tag');
      expect(result.data['target_ids'], ['tag-new']);
      expect(result.summary, contains('Would apply create_tag'));
      expect(gateway.batches, isEmpty);
      expect(gateway.state!.tags, hasLength(1));
    });

    test('unknown command tool and missing gateway fail actionably', () async {
      final gateway = FakeProjectCommandGateway(state: stateWithOneClip());
      final executor = CommandToolExecutor(_ctx(gateway: gateway));

      final unknown = await executor.execute(
        const ToolCall(id: 'c1', name: 'frobnicate_tag', args: {}),
      );
      expect(unknown.success, isFalse);
      expect(unknown.error, contains('Unknown command tool'));
      expect(gateway.batches, isEmpty);

      final noGateway = CommandToolExecutor(_ctx());
      final result = await noGateway.execute(const ToolCall(
        id: 'c2',
        name: 'create_tag',
        args: {'name': 'Music', 'color': '#AABBCC'},
      ));
      expect(result.success, isFalse);
      expect(result.error, contains('live project document'));
    });
  });

  group('ReadToolExecutor list_tags_and_markers', () {
    test('returns tags with targets, markers and assets', () async {
      final gateway = FakeProjectCommandGateway(
        state: stateWithOneClip().copyWith(
          markers: const [
            TimelineMarker(
              id: 'm1',
              label: 'Intro',
              color: '#FF0000',
              atMs: 500,
            ),
            TimelineMarker(
              id: 'm2',
              label: 'Chapter',
              color: '#00FF00',
              startMs: 100,
              endMs: 900,
            ),
          ],
        ),
      );
      final executor = ReadToolExecutor(_ctx(gateway: gateway));

      final result = await executor.execute(
        const ToolCall(id: 'r1', name: 'list_tags_and_markers'),
      );

      expect(result.success, isTrue);
      final tags = result.data['tags'] as List;
      expect(tags.single['id'], 'tag-1');
      expect(tags.single['name'], 'Travel');
      expect(tags.single['color'], '#112233');
      final targets = tags.single['targets'] as Map;
      expect(targets['assets'], ['asset-1']);
      expect(targets['clips'], ['clip-1']);

      final markers = result.data['markers'] as List;
      expect(markers, hasLength(2));
      expect(markers[0], containsPair('atMs', 500));
      expect(markers[0].containsKey('startMs'), isFalse);
      expect(markers[1], containsPair('startMs', 100));
      expect(markers[1], containsPair('endMs', 900));
      expect(markers[1].containsKey('atMs'), isFalse);

      final assets = result.data['assets'] as List;
      expect(assets.single['id'], 'asset-1');
      expect(assets.single['displayName'], 'source.mp4');
      expect(assets.single['tagIds'], ['tag-1']);

      expect(result.data['counts'], {
        'tags': 1,
        'markers': 2,
        'assets': 1,
      });
      expect(result.summary, contains('1 tag(s)'));
      expect(result.summary, contains('2 marker(s)'));
    });

    test('fails actionably when no gateway is wired', () async {
      final executor = ReadToolExecutor(_ctx());

      final result = await executor.execute(
        const ToolCall(id: 'r1', name: 'list_tags_and_markers'),
      );

      expect(result.success, isFalse);
      expect(result.error, contains('No tag/marker inventory'));
    });
  });
}
