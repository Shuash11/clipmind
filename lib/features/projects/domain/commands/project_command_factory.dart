import 'package:clipmind/core/results/result.dart';

import '../entities/clip_transform.dart';
import '../ids/id_generator.dart';
import 'clip_commands.dart';
import 'marker_commands.dart';
import 'overlay_commands.dart';
import 'project_command.dart';
import 'tag_commands.dart';

final class ProjectCommandFactory {
  const ProjectCommandFactory(this._ids);

  final IdGenerator _ids;

  TrimClipCommand trimClip({
    required String clipId,
    required int startMs,
    required int endMs,
  }) => TrimClipCommand(clipId: clipId, startMs: startMs, endMs: endMs);

  RemoveClipRangeCommand removeClipRange({
    required String clipId,
    required int startMs,
    required int endMs,
  }) => RemoveClipRangeCommand(
    clipId: clipId,
    startMs: startMs,
    endMs: endMs,
    rightClipId: _ids.next(),
  );

  ArrangeClipsCommand arrangeClips({required List<ClipPlacement> placements}) =>
      ArrangeClipsCommand(placements: placements);

  SetClipSpeedCommand setSpeed({
    required String clipId,
    required double speed,
  }) => SetClipSpeedCommand(clipId: clipId, speed: speed);

  SetClipMutedCommand setMuted({required String clipId, required bool muted}) =>
      SetClipMutedCommand(clipId: clipId, muted: muted);

  SetClipVolumeCommand setVolume({
    required String clipId,
    required double volume,
  }) => SetClipVolumeCommand(clipId: clipId, volume: volume);

  SetClipTransformCommand setTransform({
    required String clipId,
    required int width,
    required int height,
    required ClipFit fit,
    required int rotationDegrees,
  }) => SetClipTransformCommand(
    clipId: clipId,
    transform: ClipTransform(
      width: width,
      height: height,
      fit: fit,
      rotationDegrees: rotationDegrees,
    ),
  );

  SetClipBrightnessCommand setBrightness({
    required String clipId,
    required double brightness,
  }) => SetClipBrightnessCommand(clipId: clipId, brightness: brightness);

  AddTextOverlayCommand addTextOverlay({
    required String trackId,
    required int startMs,
    required int endMs,
    required String text,
    required double x,
    required double y,
  }) => AddTextOverlayCommand(
    overlayId: _ids.next(),
    trackId: trackId,
    startMs: startMs,
    endMs: endMs,
    text: text,
    x: x,
    y: y,
  );

  AddImageOverlayCommand addImageOverlay({
    required String trackId,
    required String assetId,
    required int startMs,
    required int endMs,
    required double x,
    required double y,
    required int width,
    required int height,
  }) => AddImageOverlayCommand(
    overlayId: _ids.next(),
    trackId: trackId,
    assetId: assetId,
    startMs: startMs,
    endMs: endMs,
    x: x,
    y: y,
    width: width,
    height: height,
  );

  CreateTagCommand createTag({required String name, required String color}) =>
      CreateTagCommand(tagId: _ids.next(), name: name, color: color);

  UpdateTagCommand updateTag({
    required String tagId,
    required String name,
    required String color,
  }) => UpdateTagCommand(tagId: tagId, name: name, color: color);

  DeleteTagCommand deleteTag({required String tagId}) =>
      DeleteTagCommand(tagId: tagId);

  AssignTagCommand assignTag({
    required String tagId,
    required AssignmentTargetKind targetKind,
    required String targetId,
  }) => AssignTagCommand(
    tagId: tagId,
    targetKind: targetKind,
    targetId: targetId,
  );

  UnassignTagCommand unassignTag({
    required String tagId,
    required AssignmentTargetKind targetKind,
    required String targetId,
  }) => UnassignTagCommand(
    tagId: tagId,
    targetKind: targetKind,
    targetId: targetId,
  );

  CreateMarkerCommand createMarker({
    required String label,
    required String color,
    int? atMs,
    int? startMs,
    int? endMs,
  }) => CreateMarkerCommand(
    markerId: _ids.next(),
    label: label,
    color: color,
    atMs: atMs,
    startMs: startMs,
    endMs: endMs,
  );

  UpdateMarkerCommand updateMarker({
    required String markerId,
    required String label,
    required String color,
    int? atMs,
    int? startMs,
    int? endMs,
  }) => UpdateMarkerCommand(
    markerId: markerId,
    label: label,
    color: color,
    atMs: atMs,
    startMs: startMs,
    endMs: endMs,
  );

  DeleteMarkerCommand deleteMarker({required String markerId}) =>
      DeleteMarkerCommand(markerId: markerId);

  Result<ProjectCommand> fromCanonicalArguments(
    String type,
    Map<String, Object?> arguments,
  ) {
    try {
      switch (type) {
        case 'trim_clip':
          return _require(arguments, {'clipId', 'startMs', 'endMs'})
              ? Success(
                  trimClip(
                    clipId: _string(arguments, 'clipId')!,
                    startMs: _int(arguments, 'startMs')!,
                    endMs: _int(arguments, 'endMs')!,
                  ),
                )
              : _invalid(type);
        case 'remove_clip_range':
          return _require(arguments, {'clipId', 'startMs', 'endMs'})
              ? Success(
                  removeClipRange(
                    clipId: _string(arguments, 'clipId')!,
                    startMs: _int(arguments, 'startMs')!,
                    endMs: _int(arguments, 'endMs')!,
                  ),
                )
              : _invalid(type);
        case 'arrange_clips':
          final placements = _placements(arguments);
          return placements == null
              ? _invalid(type)
              : Success(arrangeClips(placements: placements));
        case 'set_clip_speed':
          return _require(arguments, {'clipId', 'speed'})
              ? Success(
                  setSpeed(
                    clipId: _string(arguments, 'clipId')!,
                    speed: _double(arguments, 'speed')!,
                  ),
                )
              : _invalid(type);
        case 'set_clip_muted':
          return _require(arguments, {'clipId', 'muted'}) &&
                  arguments['muted'] is bool
              ? Success(
                  setMuted(
                    clipId: _string(arguments, 'clipId')!,
                    muted: arguments['muted'] as bool,
                  ),
                )
              : _invalid(type);
        case 'set_clip_volume':
          return _require(arguments, {'clipId', 'volume'})
              ? Success(
                  setVolume(
                    clipId: _string(arguments, 'clipId')!,
                    volume: _double(arguments, 'volume')!,
                  ),
                )
              : _invalid(type);
        case 'set_clip_transform':
          if (!_require(arguments, {
            'clipId',
            'width',
            'height',
            'fit',
            'rotationDegrees',
          })) {
            return _invalid(type);
          }
          final fit = _string(arguments, 'fit');
          if (fit == null ||
              !ClipFit.values.any((value) => value.name == fit)) {
            return _invalid(type);
          }
          return Success(
            setTransform(
              clipId: _string(arguments, 'clipId')!,
              width: _int(arguments, 'width')!,
              height: _int(arguments, 'height')!,
              fit: ClipFit.values.byName(fit),
              rotationDegrees: _int(arguments, 'rotationDegrees')!,
            ),
          );
        case 'set_clip_brightness':
          return _require(arguments, {'clipId', 'brightness'})
              ? Success(
                  setBrightness(
                    clipId: _string(arguments, 'clipId')!,
                    brightness: _double(arguments, 'brightness')!,
                  ),
                )
              : _invalid(type);
        case 'add_text_overlay':
          return _require(arguments, {
                'trackId',
                'startMs',
                'endMs',
                'text',
                'x',
                'y',
              })
              ? Success(
                  addTextOverlay(
                    trackId: _string(arguments, 'trackId')!,
                    startMs: _int(arguments, 'startMs')!,
                    endMs: _int(arguments, 'endMs')!,
                    text: _string(arguments, 'text')!,
                    x: _double(arguments, 'x')!,
                    y: _double(arguments, 'y')!,
                  ),
                )
              : _invalid(type);
        case 'add_image_overlay':
          return _require(arguments, {
                'trackId',
                'assetId',
                'startMs',
                'endMs',
                'x',
                'y',
                'width',
                'height',
              })
              ? Success(
                  addImageOverlay(
                    trackId: _string(arguments, 'trackId')!,
                    assetId: _string(arguments, 'assetId')!,
                    startMs: _int(arguments, 'startMs')!,
                    endMs: _int(arguments, 'endMs')!,
                    x: _double(arguments, 'x')!,
                    y: _double(arguments, 'y')!,
                    width: _int(arguments, 'width')!,
                    height: _int(arguments, 'height')!,
                  ),
                )
              : _invalid(type);
        case 'create_tag':
          return _require(arguments, {'name', 'color'})
              ? Success(
                  createTag(
                    name: _string(arguments, 'name')!,
                    color: _string(arguments, 'color')!,
                  ),
                )
              : _invalid(type);
        case 'update_tag':
          return _require(arguments, {'tagId', 'name', 'color'})
              ? Success(
                  updateTag(
                    tagId: _string(arguments, 'tagId')!,
                    name: _string(arguments, 'name')!,
                    color: _string(arguments, 'color')!,
                  ),
                )
              : _invalid(type);
        case 'delete_tag':
          return _require(arguments, {'tagId'})
              ? Success(deleteTag(tagId: _string(arguments, 'tagId')!))
              : _invalid(type);
        case 'assign_tag':
          return _assignment(arguments, true);
        case 'unassign_tag':
          return _assignment(arguments, false);
        case 'create_marker':
          return _marker(arguments, create: true);
        case 'update_marker':
          return _marker(arguments, create: false);
        case 'delete_marker':
          return _require(arguments, {'markerId'})
              ? Success(deleteMarker(markerId: _string(arguments, 'markerId')!))
              : _invalid(type);
        default:
          return _invalid(type);
      }
    } catch (_) {
      return _invalid(type);
    }
  }

  Result<ProjectCommand> _assignment(
    Map<String, Object?> arguments,
    bool assign,
  ) {
    if (!_require(arguments, {'tagId', 'targetKind', 'targetId'})) {
      return _invalid(assign ? 'assign_tag' : 'unassign_tag');
    }
    final kind = _string(arguments, 'targetKind');
    if (kind == null ||
        !AssignmentTargetKind.values.any((value) => value.name == kind)) {
      return _invalid(assign ? 'assign_tag' : 'unassign_tag');
    }
    final targetKind = AssignmentTargetKind.values.byName(kind);
    return Success(
      assign
          ? assignTag(
              tagId: _string(arguments, 'tagId')!,
              targetKind: targetKind,
              targetId: _string(arguments, 'targetId')!,
            )
          : unassignTag(
              tagId: _string(arguments, 'tagId')!,
              targetKind: targetKind,
              targetId: _string(arguments, 'targetId')!,
            ),
    );
  }

  Result<ProjectCommand> _marker(
    Map<String, Object?> arguments, {
    required bool create,
  }) {
    final allowed = create
        ? {'label', 'color', 'atMs', 'startMs', 'endMs'}
        : {'markerId', 'label', 'color', 'atMs', 'startMs', 'endMs'};
    if (!_allow(arguments, allowed) ||
        _string(arguments, 'label') == null ||
        _string(arguments, 'color') == null) {
      return _invalid(create ? 'create_marker' : 'update_marker');
    }
    final atMs = _nullableInt(arguments, 'atMs');
    final startMs = _nullableInt(arguments, 'startMs');
    final endMs = _nullableInt(arguments, 'endMs');
    if ((atMs == null && (startMs == null || endMs == null)) ||
        (atMs != null && (startMs != null || endMs != null))) {
      return _invalid(create ? 'create_marker' : 'update_marker');
    }
    return Success(
      create
          ? createMarker(
              label: _string(arguments, 'label')!,
              color: _string(arguments, 'color')!,
              atMs: atMs,
              startMs: startMs,
              endMs: endMs,
            )
          : updateMarker(
              markerId: _string(arguments, 'markerId')!,
              label: _string(arguments, 'label')!,
              color: _string(arguments, 'color')!,
              atMs: atMs,
              startMs: startMs,
              endMs: endMs,
            ),
    );
  }

  List<ClipPlacement>? _placements(Map<String, Object?> arguments) {
    if (!_require(arguments, {'placements'})) return null;
    final raw = arguments['placements'];
    if (raw is! List || raw.isEmpty || raw.length > 100) return null;
    final placements = <ClipPlacement>[];
    for (final value in raw) {
      if (value is! Map) return null;
      final map = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) return null;
        map[entry.key as String] = entry.value;
      }
      if (!_require(map, {'clipId', 'trackId', 'positionMs'})) return null;
      placements.add(
        ClipPlacement(
          clipId: _string(map, 'clipId')!,
          trackId: _string(map, 'trackId')!,
          positionMs: _int(map, 'positionMs')!,
        ),
      );
    }
    return placements;
  }

  bool _require(Map<String, Object?> map, Set<String> keys) =>
      _allow(map, keys) &&
      keys.every(map.containsKey) &&
      keys.every((key) => _valueMatches(map[key]));

  bool _allow(Map<String, Object?> map, Set<String> keys) =>
      map.keys.every(keys.contains);

  bool _valueMatches(Object? value) => value != null;
  String? _string(Map<String, Object?> map, String key) =>
      map[key] is String ? map[key] as String : null;

  int? _int(Map<String, Object?> map, String key) =>
      map[key] is int ? map[key] as int : null;

  int? _nullableInt(Map<String, Object?> map, String key) =>
      !map.containsKey(key) || map[key] == null ? null : _int(map, key);

  double? _double(Map<String, Object?> map, String key) =>
      map[key] is num ? (map[key] as num).toDouble() : null;

  Result<ProjectCommand> _invalid(String type) =>
      Failure(ProjectValidationFailure('Invalid $type arguments'));
}
