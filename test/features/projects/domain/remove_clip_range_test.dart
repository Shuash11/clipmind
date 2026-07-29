import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/entities/clip_transform.dart';
import 'package:clipmind/features/projects/domain/entities/project_clip.dart';
import 'package:clipmind/features/projects/domain/entities/project_track.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';
import '../support/project_test_data.dart';

void main() {
  CommandExecution execute(int startMs, int endMs) {
    final command = ProjectCommandFactory(
      SequenceIdGenerator(['right-clip']),
    ).removeClipRange(clipId: 'clip-1', startMs: startMs, endMs: endMs);
    return (ProjectCommandExecutor.standard().applyAll(stateWithOneClip(), [
              command,
            ])
            as Success<CommandExecution>)
        .value;
  }

  test('prefix removal trims the clip using clip-local offsets', () {
    final clip = execute(0, 200).candidateState.tracks.single.clips.single;
    expect(clip.startMs, 200);
    expect(clip.endMs, 1000);
    expect(clip.positionMs, 0);
  });

  test('suffix removal trims the clip using clip-local offsets', () {
    final clip = execute(800, 1000).candidateState.tracks.single.clips.single;
    expect(clip.startMs, 0);
    expect(clip.endMs, 800);
  });

  test(
    'interior removal splits with factory ID and closes the timeline gap',
    () {
      final original = stateWithOneClip(
        startMs: 0,
        endMs: 1000,
        positionMs: 100,
        speed: 1.25,
        muted: true,
        volume: 0.4,
        brightness: -0.3,
      );
      final before = original.copyWith(
        tracks: [
          original.tracks.single.copyWith(
            clips: [
              original.tracks.single.clips.single,
              ProjectClip(
                id: 'later-clip',
                assetId: 'asset-1',
                trackId: 'track-1',
                startMs: 0,
                endMs: 100,
                positionMs: 1100,
                tagIds: {'tag-1'},
                transform: const ClipTransform(
                  width: 1920,
                  height: 1080,
                  fit: ClipFit.contain,
                  rotationDegrees: 0,
                ),
                speed: 1,
                muted: false,
                volume: 1,
              ),
            ],
          ),
          ProjectTrack(
            id: 'track-2',
            kind: ProjectTrackKind.video,
            clips: [
              ProjectClip(
                id: 'other-track-clip',
                assetId: 'asset-1',
                trackId: 'track-2',
                startMs: 0,
                endMs: 100,
                positionMs: 1100,
                tagIds: {'tag-1'},
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
      );
      final command = ProjectCommandFactory(
        SequenceIdGenerator(['right-clip']),
      ).removeClipRange(clipId: 'clip-1', startMs: 250, endMs: 500);
      final result = ProjectCommandExecutor.standard().applyAll(before, [
        command,
      ]);
      final execution = (result as Success<CommandExecution>).value;
      final clips = execution.candidateState.tracks
          .singleWhere((ProjectTrack track) => track.id == 'track-1')
          .clips;
      expect(clips.map((ProjectClip clip) => clip.id), [
        'clip-1',
        'right-clip',
        'later-clip',
      ]);
      expect(clips[0].endMs, 250);
      expect(clips[1].startMs, 500);
      expect(clips[1].endMs, 1000);
      expect(clips[1].positionMs, 350);
      expect(clips[1].assetId, 'asset-1');
      expect(clips[1].tagIds, {'tag-1'});
      expect(
        clips[1].transform,
        before.tracks
            .singleWhere((ProjectTrack track) => track.id == 'track-1')
            .clips
            .singleWhere((ProjectClip clip) => clip.id == 'clip-1')
            .transform,
      );
      expect(clips[1].speed, 1.25);
      expect(clips[1].muted, isTrue);
      expect(clips[1].volume, 0.4);
      expect(clips[1].brightness, -0.3);
      expect(clips[2].positionMs, 850);
      expect(
        execution.candidateState.tracks
            .singleWhere((ProjectTrack track) => track.id == 'track-2')
            .clips
            .single
            .positionMs,
        1100,
      );
    },
  );

  test(
    'removing the entire clip is rejected rather than producing zero duration',
    () {
      final command = ProjectCommandFactory(
        SequenceIdGenerator(['right-clip']),
      ).removeClipRange(clipId: 'clip-1', startMs: 0, endMs: 1000);
      expect(
        ProjectCommandExecutor.standard().applyAll(stateWithOneClip(), [
          command,
        ]),
        isA<Failure<CommandExecution>>(),
      );
    },
  );
}
