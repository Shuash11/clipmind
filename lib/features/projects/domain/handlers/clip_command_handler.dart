import 'package:clipmind/core/results/result.dart';

import '../commands/clip_commands.dart';
import '../commands/project_command.dart';
import '../entities/project_clip.dart';
import '../entities/project_state_snapshot.dart';
import '../entities/project_track.dart';
import 'command_handler_result.dart';

final class ClipCommandHandler {
  const ClipCommandHandler();

  bool handles(ProjectCommand command) =>
      command is TrimClipCommand ||
      command is RemoveClipRangeCommand ||
      command is ArrangeClipsCommand ||
      command is SetClipSpeedCommand ||
      command is SetClipMutedCommand ||
      command is SetClipVolumeCommand ||
      command is SetClipTransformCommand ||
      command is SetClipBrightnessCommand;

  Result<CommandHandlerResult> apply(
    ProjectStateSnapshot state,
    ProjectCommand command,
  ) {
    if (command is TrimClipCommand) return _trim(state, command);
    if (command is RemoveClipRangeCommand) {
      return _removeRange(state, command);
    }
    if (command is ArrangeClipsCommand) return _arrange(state, command);
    if (command is SetClipSpeedCommand) {
      return _updateClip(
        state,
        command,
        (clip) =>
            _finite(command.speed) && command.speed >= .25 && command.speed <= 8
            ? clip.copyWith(speed: command.speed)
            : null,
      );
    }
    if (command is SetClipMutedCommand) {
      return _updateClip(
        state,
        command,
        (clip) => clip.copyWith(muted: command.muted),
      );
    }
    if (command is SetClipVolumeCommand) {
      return _updateClip(
        state,
        command,
        (clip) =>
            _finite(command.volume) &&
                command.volume >= 0 &&
                command.volume <= 2
            ? clip.copyWith(volume: command.volume)
            : null,
      );
    }
    if (command is SetClipTransformCommand) {
      return _updateClip(
        state,
        command,
        (clip) => _validTransform(command)
            ? clip.copyWith(transform: command.transform)
            : null,
      );
    }
    if (command is SetClipBrightnessCommand) {
      return _updateClip(
        state,
        command,
        (clip) =>
            _finite(command.brightness) &&
                command.brightness >= -1 &&
                command.brightness <= 1
            ? clip.copyWith(brightness: command.brightness)
            : null,
      );
    }
    return const Failure(ProjectValidationFailure('Unsupported clip command'));
  }

  Result<CommandHandlerResult> _trim(
    ProjectStateSnapshot state,
    TrimClipCommand command,
  ) {
    return _updateClip(
      state,
      command,
      (clip) =>
          command.startMs >= 0 &&
              command.startMs < command.endMs &&
              command.endMs <= clip.durationMs
          ? clip.copyWith(
              startMs: clip.startMs + command.startMs,
              endMs: clip.startMs + command.endMs,
            )
          : null,
    );
  }

  Result<CommandHandlerResult> _removeRange(
    ProjectStateSnapshot state,
    RemoveClipRangeCommand command,
  ) {
    final located = _locateClip(state, command.clipId);
    if (located == null) {
      return const Failure(ProjectValidationFailure('Unknown clip'));
    }
    final target = located.clip;
    if (command.startMs < 0 ||
        command.startMs >= command.endMs ||
        command.endMs > target.durationMs ||
        (command.startMs == 0 && command.endMs == target.durationMs)) {
      return const Failure(
        ProjectValidationFailure('Invalid clip removal range'),
      );
    }

    final removedDuration = command.endMs - command.startMs;
    final updatedTracks = state.tracks.map((track) {
      if (track.id != located.track.id) return track;
      final clips = <ProjectClip>[];
      for (final clip in track.clips) {
        if (clip.id != target.id) {
          clips.add(
            clip.positionMs > target.positionMs
                ? clip.copyWith(positionMs: clip.positionMs - removedDuration)
                : clip,
          );
          continue;
        }
        if (command.startMs == 0) {
          clips.add(clip.copyWith(startMs: clip.startMs + command.endMs));
        } else if (command.endMs == clip.durationMs) {
          clips.add(clip.copyWith(endMs: clip.startMs + command.startMs));
        } else {
          clips.add(clip.copyWith(endMs: clip.startMs + command.startMs));
          clips.add(
            clip.copyWith(
              id: command.rightClipId,
              startMs: clip.startMs + command.endMs,
              positionMs: clip.positionMs + command.startMs,
            ),
          );
        }
      }
      clips.sort((left, right) => left.positionMs.compareTo(right.positionMs));
      return track.copyWith(clips: clips);
    }).toList();

    final targetIds = <String>[target.id];
    if (command.startMs > 0 && command.endMs < target.durationMs) {
      targetIds.add(command.rightClipId);
    }
    return Success(
      CommandHandlerResult(
        state: state.copyWith(tracks: updatedTracks),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: targetIds,
        ),
      ),
    );
  }

  Result<CommandHandlerResult> _arrange(
    ProjectStateSnapshot state,
    ArrangeClipsCommand command,
  ) {
    if (command.placements.isEmpty || command.placements.length > 100) {
      return const Failure(ProjectValidationFailure('Invalid placements'));
    }
    final knownClips = <String, ProjectClip>{
      for (final track in state.tracks)
        for (final clip in track.clips) clip.id: clip,
    };
    final trackIds = state.tracks.map((track) => track.id).toSet();
    final placed = <String>{};
    for (final placement in command.placements) {
      if (!placed.add(placement.clipId) ||
          !knownClips.containsKey(placement.clipId) ||
          !trackIds.contains(placement.trackId) ||
          placement.positionMs < 0) {
        return const Failure(
          ProjectValidationFailure('Invalid clip placement'),
        );
      }
    }

    final withoutMoved = state.tracks
        .map(
          (track) => track.copyWith(
            clips: track.clips
                .where((clip) => !placed.contains(clip.id))
                .toList(),
          ),
        )
        .toList();
    final mutable = <String, List<ProjectClip>>{
      for (final track in withoutMoved) track.id: [...track.clips],
    };
    for (final placement in command.placements) {
      final clip = knownClips[placement.clipId]!;
      mutable[placement.trackId]!.add(
        clip.copyWith(
          trackId: placement.trackId,
          positionMs: placement.positionMs,
        ),
      );
    }
    final tracks = withoutMoved.map((track) {
      final clips = mutable[track.id]!;
      clips.sort((left, right) => left.positionMs.compareTo(right.positionMs));
      return track.copyWith(clips: clips);
    }).toList();
    return Success(
      CommandHandlerResult(
        state: state.copyWith(tracks: tracks),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: command.placements
              .map((placement) => placement.clipId)
              .toList(),
        ),
      ),
    );
  }

  Result<CommandHandlerResult> _updateClip(
    ProjectStateSnapshot state,
    ProjectCommand command,
    ProjectClip? Function(ProjectClip clip) update,
  ) {
    final clipId = _clipId(command);
    if (clipId == null) {
      return const Failure(ProjectValidationFailure('Missing clip identifier'));
    }
    var changed = false;
    final tracks = state.tracks.map((track) {
      return track.copyWith(
        clips: track.clips.map((clip) {
          if (clip.id != clipId) return clip;
          final updated = update(clip);
          if (updated == null) return clip;
          changed = true;
          return updated;
        }).toList(),
      );
    }).toList();
    if (!changed) {
      return Failure(
        ProjectValidationFailure('Invalid ${command.type} target or value'),
      );
    }
    return Success(
      CommandHandlerResult(
        state: state.copyWith(tracks: tracks),
        summary: CanonicalCommandSummary(
          type: command.type,
          targetIds: [clipId],
        ),
      ),
    );
  }

  _LocatedClip? _locateClip(ProjectStateSnapshot state, String clipId) {
    for (final track in state.tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipId) return _LocatedClip(track, clip);
      }
    }
    return null;
  }

  String? _clipId(ProjectCommand command) {
    if (command is TrimClipCommand) return command.clipId;
    if (command is SetClipSpeedCommand) return command.clipId;
    if (command is SetClipMutedCommand) return command.clipId;
    if (command is SetClipVolumeCommand) return command.clipId;
    if (command is SetClipTransformCommand) return command.clipId;
    if (command is SetClipBrightnessCommand) return command.clipId;
    return null;
  }

  bool _validTransform(SetClipTransformCommand command) =>
      command.transform.width >= 16 &&
      command.transform.width <= 7680 &&
      command.transform.height >= 16 &&
      command.transform.height <= 4320 &&
      command.transform.rotationDegrees >= 0 &&
      command.transform.rotationDegrees <= 359;

  bool _finite(double value) => value.isFinite;
}

final class _LocatedClip {
  const _LocatedClip(this.track, this.clip);

  final ProjectTrack track;
  final ProjectClip clip;
}
