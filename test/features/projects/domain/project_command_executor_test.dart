import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/clip_commands.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_test_data.dart';

void main() {
  test('executor exposes exactly the 18 canonical command types', () {
    expect(ProjectCommandExecutor.standard().supportedTypes, {
      'trim_clip',
      'remove_clip_range',
      'arrange_clips',
      'set_clip_speed',
      'set_clip_muted',
      'set_clip_volume',
      'set_clip_transform',
      'set_clip_brightness',
      'add_text_overlay',
      'add_image_overlay',
      'create_tag',
      'update_tag',
      'delete_tag',
      'assign_tag',
      'unassign_tag',
      'create_marker',
      'update_marker',
      'delete_marker',
    });
  });

  test('executor applies commands in order into one candidate', () {
    final result = ProjectCommandExecutor.standard()
        .applyAll(stateWithOneClip(), const [
          SetClipBrightnessCommand(clipId: 'clip-1', brightness: -0.2),
          SetClipVolumeCommand(clipId: 'clip-1', volume: 0.5),
        ]);
    final execution = (result as Success<CommandExecution>).value;
    final clip = execution.candidateState.tracks.single.clips.single;
    expect(clip.brightness, -0.2);
    expect(clip.volume, 0.5);
    expect(execution.summaries, hasLength(2));
  });

  test('invalid later command returns failure without a partial candidate', () {
    final before = stateWithOneClip();
    final result = ProjectCommandExecutor.standard().applyAll(before, const [
      SetClipBrightnessCommand(clipId: 'clip-1', brightness: -0.2),
      SetClipVolumeCommand(clipId: 'missing', volume: 0.5),
    ]);
    expect(result, isA<Failure<CommandExecution>>());
    expect(before.tracks.single.clips.single.brightness, isNot(-0.2));
  });
}
