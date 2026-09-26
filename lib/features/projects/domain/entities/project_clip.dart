import 'clip_transform.dart';
import 'value_utils.dart';

final class ProjectClip {
  ProjectClip({
    required this.id,
    required this.assetId,
    required this.trackId,
    required this.startMs,
    required this.endMs,
    required this.positionMs,
    required Set<String> tagIds,
    required this.transform,
    required this.speed,
    required this.muted,
    required this.volume,
    this.brightness = 0,
  }) : tagIds = Set.unmodifiable(tagIds);

  final String id;
  final String assetId;
  final String trackId;
  final int startMs;
  final int endMs;
  final int positionMs;
  final Set<String> tagIds;
  final ClipTransform transform;
  final double speed;
  final bool muted;
  final double volume;
  final double brightness;

  int get durationMs => endMs - startMs;

  ProjectClip copyWith({
    String? id,
    String? assetId,
    String? trackId,
    int? startMs,
    int? endMs,
    int? positionMs,
    Set<String>? tagIds,
    ClipTransform? transform,
    double? speed,
    bool? muted,
    double? volume,
    double? brightness,
  }) => ProjectClip(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    trackId: trackId ?? this.trackId,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    positionMs: positionMs ?? this.positionMs,
    tagIds: tagIds ?? this.tagIds,
    transform: transform ?? this.transform,
    speed: speed ?? this.speed,
    muted: muted ?? this.muted,
    volume: volume ?? this.volume,
    brightness: brightness ?? this.brightness,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'assetId': assetId,
    'trackId': trackId,
    'startMs': startMs,
    'endMs': endMs,
    'positionMs': positionMs,
    'tagIds': tagIds.toList(),
    'transform': transform.toJson(),
    'speed': speed,
    'muted': muted,
    'volume': volume,
    'brightness': brightness,
  };

  factory ProjectClip.fromJson(Map<String, Object?> json) => ProjectClip(
    id: json['id'] as String,
    assetId: json['assetId'] as String,
    trackId: json['trackId'] as String,
    startMs: json['startMs'] as int,
    endMs: json['endMs'] as int,
    positionMs: json['positionMs'] as int,
    tagIds: Set<String>.from(
      (json['tagIds'] as List<Object?>? ?? const []).cast<String>(),
    ),
    transform: ClipTransform.fromJson(
      Map<String, Object?>.from(json['transform'] as Map),
    ),
    speed: (json['speed'] as num).toDouble(),
    muted: json['muted'] as bool,
    volume: (json['volume'] as num).toDouble(),
    brightness: (json['brightness'] as num? ?? 0).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is ProjectClip &&
      id == other.id &&
      assetId == other.assetId &&
      trackId == other.trackId &&
      startMs == other.startMs &&
      endMs == other.endMs &&
      positionMs == other.positionMs &&
      setEquals(tagIds, other.tagIds) &&
      transform == other.transform &&
      speed == other.speed &&
      muted == other.muted &&
      volume == other.volume &&
      brightness == other.brightness;

  @override
  int get hashCode => Object.hash(
    id,
    assetId,
    trackId,
    startMs,
    endMs,
    positionMs,
    setHash(tagIds),
    transform,
    speed,
    muted,
    volume,
    brightness,
  );
}
