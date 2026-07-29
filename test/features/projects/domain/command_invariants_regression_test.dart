import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/clip_commands.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';
import 'package:clipmind/features/projects/domain/entities/project_clip.dart';
import 'package:clipmind/features/projects/domain/entities/project_track.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_test_data.dart';

void main() {
  test(
    'cross-track arrange is atomic and invalid later placement returns no candidate',
    () {
      final original = stateWithOneClip();
      final before = original.copyWith(
        tracks: [
          ...original.tracks,
          ProjectTrack(
            id: 'track-2',
            kind: ProjectTrackKind.video,
            clips: [
              ProjectClip(
                id: 'clip-2',
                assetId: 'asset-1',
                trackId: 'track-2',
                startMs: 0,
                endMs: 100,
                positionMs: 0,
                tagIds: const {},
                transform: original.tracks.single.clips.single.transform,
                speed: 1,
                muted: false,
                volume: 1,
              ),
            ],
          ),
        ],
      );
      final result = ProjectCommandExecutor.standard().applyAll(before, [
        ArrangeClipsCommand(
          placements: const [
            ClipPlacement(clipId: 'clip-1', trackId: 'track-2', positionMs: 50),
          ],
        ),
        ArrangeClipsCommand(
          placements: const [
            ClipPlacement(clipId: 'clip-2', trackId: 'missing', positionMs: 0),
          ],
        ),
      ]);
      expect(result, isA<Failure<CommandExecution>>());
      expect(
        before.tracks
            .singleWhere((ProjectTrack track) => track.id == 'track-1')
            .clips
            .single
            .id,
        'clip-1',
      );
      expect(
        before.tracks
            .singleWhere((ProjectTrack track) => track.id == 'track-2')
            .clips
            .single
            .id,
        'clip-2',
      );
    },
  );

  test('tag collision and assignment no-op are rejected', () {
    final state = stateWithOneClip();
    final executor = ProjectCommandExecutor.standard();
    expect(
      executor.applyAll(state, const [
        CreateTagCommand(tagId: 'tag-2', name: ' travel ', color: '#112233'),
      ]),
      isA<Failure<CommandExecution>>(),
    );
    expect(
      executor.applyAll(state, const [
        AssignTagCommand(
          tagId: 'tag-1',
          targetKind: AssignmentTargetKind.asset,
          targetId: 'asset-1',
        ),
      ]),
      isA<Failure<CommandExecution>>(),
    );
  });

  test('duplicate IDs and nonfinite clip values are rejected', () {
    final state = stateWithOneClip();
    final executor = ProjectCommandExecutor.standard();
    expect(
      executor.applyAll(state, const [
        CreateTagCommand(tagId: 'tag-1', name: 'Other', color: '#445566'),
      ]),
      isA<Failure<CommandExecution>>(),
    );
    expect(
      executor.applyAll(state, const [
        SetClipBrightnessCommand(clipId: 'clip-1', brightness: double.nan),
      ]),
      isA<Failure<CommandExecution>>(),
    );
    expect(
      executor.applyAll(state, const [
        SetClipVolumeCommand(clipId: 'clip-1', volume: double.infinity),
      ]),
      isA<Failure<CommandExecution>>(),
    );
  });
}
