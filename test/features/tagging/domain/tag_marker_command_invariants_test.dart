import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';
import 'package:clipmind/features/projects/domain/entities/media_asset.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';
import 'package:clipmind/features/projects/domain/entities/tag_definition.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  final executor = ProjectCommandExecutor.standard();

  test('rejects normalized duplicate tag names on creation and update', () {
    final factory = _factory(['tag-2']);
    final state = stateWithOneClip().copyWith(
      tags: const [
        TagDefinition(id: 'tag-1', name: 'Travel', color: '#112233'),
        TagDefinition(id: 'tag-2', name: 'Work', color: '#445566'),
      ],
    );

    expect(
      executor.applyAll(state, [
        factory.createTag(name: '  TRAVEL ', color: '#AABBCC'),
      ]),
      isA<Failure<CommandExecution>>(),
    );
    expect(
      executor.applyAll(state, [
        factory.updateTag(tagId: 'tag-2', name: ' travel ', color: '#AABBCC'),
      ]),
      isA<Failure<CommandExecution>>(),
    );
  });

  test('requires strict #RRGGBB colors for tags and markers', () {
    final state = stateWithOneClip();

    for (final color in ['112233', '#12345', '#1234567', '#12GG33']) {
      expect(
        executor.applyAll(state, [
          _factory(['tag-$color']).createTag(name: 'New', color: color),
        ]),
        isA<Failure<CommandExecution>>(),
      );
      expect(
        executor.applyAll(state, [
          _factory([
            'marker-$color',
          ]).createMarker(label: 'Beat', color: color, atMs: 10),
        ]),
        isA<Failure<CommandExecution>>(),
      );
    }
  });

  test(
    'requires existing targets and rejects assignment and unassignment no-ops',
    () {
      final state = stateWithOneClip();
      final factory = _factory(const []);

      expect(
        executor.applyAll(state, [
          factory.assignTag(
            tagId: 'tag-1',
            targetKind: AssignmentTargetKind.asset,
            targetId: 'missing-asset',
          ),
        ]),
        isA<Failure<CommandExecution>>(),
      );
      expect(
        executor.applyAll(state, [
          factory.unassignTag(
            tagId: 'tag-1',
            targetKind: AssignmentTargetKind.clip,
            targetId: 'missing-clip',
          ),
        ]),
        isA<Failure<CommandExecution>>(),
      );
      expect(
        executor.applyAll(state, [
          factory.assignTag(
            tagId: 'tag-1',
            targetKind: AssignmentTargetKind.asset,
            targetId: 'asset-1',
          ),
        ]),
        isA<Failure<CommandExecution>>(),
      );
      final withoutTag = state.copyWith(
        assets: [state.assets.single.copyWith(tagIds: const {})],
      );
      expect(
        executor.applyAll(withoutTag, [
          factory.unassignTag(
            tagId: 'tag-1',
            targetKind: AssignmentTargetKind.asset,
            targetId: 'asset-1',
          ),
        ]),
        isA<Failure<CommandExecution>>(),
      );
    },
  );

  test('accepts only a non-negative point or a positive range marker', () {
    final state = stateWithOneClip();

    expect(
      executor.applyAll(state, [
        _factory([
          'point',
        ]).createMarker(label: 'Point', color: '#112233', atMs: 0),
      ]),
      isA<Success<CommandExecution>>(),
    );
    expect(
      executor.applyAll(state, [
        _factory(['range']).createMarker(
          label: 'Range',
          color: '#112233',
          startMs: 10,
          endMs: 20,
        ),
      ]),
      isA<Success<CommandExecution>>(),
    );
    for (final command in [
      _factory([
        'negative',
      ]).createMarker(label: 'Negative', color: '#112233', atMs: -1),
      _factory([
        'empty',
      ]).createMarker(label: 'Empty', color: '#112233', startMs: 20, endMs: 20),
      _factory(['both']).createMarker(
        label: 'Both',
        color: '#112233',
        atMs: 10,
        startMs: 10,
        endMs: 20,
      ),
      _factory([
        'incomplete',
      ]).createMarker(label: 'Incomplete', color: '#112233', startMs: 10),
    ]) {
      expect(
        executor.applyAll(state, [command]),
        isA<Failure<CommandExecution>>(),
      );
    }
  });

  test(
    'a later invalid command returns no candidate and leaves source unchanged',
    () {
      final before = stateWithOneClip();
      final original = ProjectStateSnapshot.fromJson(before.toJson());
      final factory = _factory(['tag-2', 'marker-1']);

      final result = executor.applyAll(before, [
        factory.createTag(name: 'New', color: '#112233'),
        factory.createMarker(label: 'Bad', color: 'not-a-color', atMs: 10),
      ]);

      expect(result, isA<Failure<CommandExecution>>());
      expect(before, original);
      expect(before.tags.map((tag) => tag.id), ['tag-1']);
      expect(before.markers, isEmpty);
      expect(before.assets.single.tagIds, {'tag-1'});
    },
  );

  test(
    'deleting a tag reports tag and all affected assignments deterministically',
    () {
      final base = stateWithOneClip();
      final state = base.copyWith(
        assets: [
          ...base.assets,
          MediaAsset(
            id: 'asset-2',
            sourcePath: '/media/two.mov',
            displayName: 'two.mov',
            durationMs: 1000,
            tagIds: const {'tag-1'},
          ),
        ],
        tracks: [
          base.tracks.single.copyWith(
            clips: [
              ...base.tracks.single.clips,
              base.tracks.single.clips.single.copyWith(
                id: 'clip-2',
                positionMs: 1000,
              ),
            ],
          ),
        ],
      );

      final result = executor.applyAll(state, [
        _factory(const []).deleteTag(tagId: 'tag-1'),
      ]);
      final execution = (result as Success<CommandExecution>).value;

      expect(execution.summaries.single.targetIds, [
        'tag-1',
        'asset-1',
        'asset-2',
        'clip-1',
        'clip-2',
      ]);
      expect(execution.candidateState.tags, isEmpty);
      expect(
        execution.candidateState.assets.every(
          (asset) => !asset.tagIds.contains('tag-1'),
        ),
        isTrue,
      );
      expect(
        execution.candidateState.tracks.single.clips.every(
          (clip) => !clip.tagIds.contains('tag-1'),
        ),
        isTrue,
      );
    },
  );
}

ProjectCommandFactory _factory(Iterable<String> ids) =>
    ProjectCommandFactory(SequenceIdGenerator(ids));
