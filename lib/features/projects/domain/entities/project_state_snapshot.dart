import 'media_asset.dart';
import 'project_overlay.dart';
import 'project_track.dart';
import 'tag_definition.dart';
import 'timeline_marker.dart';
import 'value_utils.dart';

final class ProjectStateSnapshot {
  ProjectStateSnapshot({
    required List<MediaAsset> assets,
    required List<ProjectTrack> tracks,
    required List<TagDefinition> tags,
    required List<TimelineMarker> markers,
    required List<ProjectOverlay> overlays,
  }) : assets = List.unmodifiable(assets),
       tracks = List.unmodifiable(tracks),
       tags = List.unmodifiable(tags),
       markers = List.unmodifiable(markers),
       overlays = List.unmodifiable(overlays);

  final List<MediaAsset> assets;
  final List<ProjectTrack> tracks;
  final List<TagDefinition> tags;
  final List<TimelineMarker> markers;
  final List<ProjectOverlay> overlays;

  MediaAsset? assetById(String id) =>
      assets.where((asset) => asset.id == id).firstOrNull;
  ProjectStateSnapshot copyWith({
    List<MediaAsset>? assets,
    List<ProjectTrack>? tracks,
    List<TagDefinition>? tags,
    List<TimelineMarker>? markers,
    List<ProjectOverlay>? overlays,
  }) => ProjectStateSnapshot(
    assets: assets ?? this.assets,
    tracks: tracks ?? this.tracks,
    tags: tags ?? this.tags,
    markers: markers ?? this.markers,
    overlays: overlays ?? this.overlays,
  );

  Map<String, Object?> toJson() => {
    'assets': assets.map((value) => value.toJson()).toList(),
    'tracks': tracks.map((value) => value.toJson()).toList(),
    'tags': tags.map((value) => value.toJson()).toList(),
    'markers': markers.map((value) => value.toJson()).toList(),
    'overlays': overlays.map((value) => value.toJson()).toList(),
  };

  factory ProjectStateSnapshot.fromJson(
    Map<String, Object?> json,
  ) => ProjectStateSnapshot(
    assets: (json['assets'] as List<Object?>? ?? const [])
        .map(
          (value) =>
              MediaAsset.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(),
    tracks: (json['tracks'] as List<Object?>? ?? const [])
        .map(
          (value) =>
              ProjectTrack.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(),
    tags: (json['tags'] as List<Object?>? ?? const [])
        .map(
          (value) =>
              TagDefinition.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(),
    markers: (json['markers'] as List<Object?>? ?? const [])
        .map(
          (value) =>
              TimelineMarker.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(),
    overlays: (json['overlays'] as List<Object?>? ?? const [])
        .map(
          (value) =>
              ProjectOverlay.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(),
  );

  @override
  bool operator ==(Object other) =>
      other is ProjectStateSnapshot &&
      listEquals(assets, other.assets) &&
      listEquals(tracks, other.tracks) &&
      listEquals(tags, other.tags) &&
      listEquals(markers, other.markers) &&
      listEquals(overlays, other.overlays);

  @override
  int get hashCode => Object.hash(
    listHash(assets),
    listHash(tracks),
    listHash(tags),
    listHash(markers),
    listHash(overlays),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
