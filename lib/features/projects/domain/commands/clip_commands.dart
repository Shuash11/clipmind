import '../entities/clip_transform.dart';
import 'project_command.dart';

final class TrimClipCommand extends ProjectCommand {
  const TrimClipCommand({
    required this.clipId,
    required this.startMs,
    required this.endMs,
  });

  final String clipId;
  final int startMs;
  final int endMs;

  @override
  String get type => 'trim_clip';
}

final class RemoveClipRangeCommand extends ProjectCommand {
  const RemoveClipRangeCommand({
    required this.clipId,
    required this.startMs,
    required this.endMs,
    required this.rightClipId,
  });

  final String clipId;
  final int startMs;
  final int endMs;
  final String rightClipId;

  @override
  String get type => 'remove_clip_range';
}

final class ClipPlacement {
  const ClipPlacement({
    required this.clipId,
    required this.trackId,
    required this.positionMs,
  });

  final String clipId;
  final String trackId;
  final int positionMs;
}

final class ArrangeClipsCommand extends ProjectCommand {
  ArrangeClipsCommand({required List<ClipPlacement> placements})
    : placements = List.unmodifiable(placements);

  final List<ClipPlacement> placements;

  @override
  String get type => 'arrange_clips';
}

final class SetClipSpeedCommand extends ProjectCommand {
  const SetClipSpeedCommand({required this.clipId, required this.speed});

  final String clipId;
  final double speed;

  @override
  String get type => 'set_clip_speed';
}

final class SetClipMutedCommand extends ProjectCommand {
  const SetClipMutedCommand({required this.clipId, required this.muted});

  final String clipId;
  final bool muted;

  @override
  String get type => 'set_clip_muted';
}

final class SetClipVolumeCommand extends ProjectCommand {
  const SetClipVolumeCommand({required this.clipId, required this.volume});

  final String clipId;
  final double volume;

  @override
  String get type => 'set_clip_volume';
}

final class SetClipTransformCommand extends ProjectCommand {
  const SetClipTransformCommand({
    required this.clipId,
    required this.transform,
  });

  final String clipId;
  final ClipTransform transform;

  @override
  String get type => 'set_clip_transform';
}

final class SetClipBrightnessCommand extends ProjectCommand {
  const SetClipBrightnessCommand({
    required this.clipId,
    required this.brightness,
  });

  final String clipId;
  final double brightness;

  @override
  String get type => 'set_clip_brightness';
}
