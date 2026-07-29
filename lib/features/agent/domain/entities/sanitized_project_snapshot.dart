import 'package:clipmind/features/projects/domain/entities/project_document.dart';

import 'safe_json_value.dart';

/// The only project representation that may be handed to a model provider.
///
/// It is intentionally constructed field-by-field rather than starting from a
/// persistence JSON document: local paths, history, output settings, and other
/// local metadata therefore have no route into this value.
final class SanitizedProjectSnapshot {
  SanitizedProjectSnapshot._(Map<String, Object?> providerJson)
    : _providerJson = immutableSafeJsonMap(providerJson);

  final Map<String, Object?> _providerJson;

  factory SanitizedProjectSnapshot.fromDocument(ProjectDocument document) {
    final state = document.currentState;
    return SanitizedProjectSnapshot._({
      'projectId': document.id,
      'projectName': _safeDisplayLabel(document.name, 'Project ${document.id}'),
      'baseRevision': document.revision,
      'assets': state.assets
          .map(
            (asset) => <String, Object?>{
              'assetId': asset.id,
              'label': _safeDisplayLabel(
                asset.displayName,
                'Asset ${asset.id}',
              ),
              'durationMs': asset.durationMs,
              'tagIds': _sortedIds(asset.tagIds),
            },
          )
          .toList(growable: false),
      'tracks': state.tracks
          .map(
            (track) => <String, Object?>{
              'trackId': track.id,
              'kind': track.kind.name,
              'clips': track.clips
                  .map(
                    (clip) => <String, Object?>{
                      'clipId': clip.id,
                      'assetId': clip.assetId,
                      'trackId': clip.trackId,
                      'startMs': clip.startMs,
                      'endMs': clip.endMs,
                      'positionMs': clip.positionMs,
                      'tagIds': _sortedIds(clip.tagIds),
                      'speed': clip.speed,
                      'muted': clip.muted,
                      'volume': clip.volume,
                      'brightness': clip.brightness,
                      'transform': <String, Object?>{
                        'width': clip.transform.width,
                        'height': clip.transform.height,
                        'fit': clip.transform.fit.name,
                        'rotationDegrees': clip.transform.rotationDegrees,
                      },
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'tags': state.tags
          .map(
            (tag) => <String, Object?>{
              'tagId': tag.id,
              'name': tag.name,
              'color': tag.color,
            },
          )
          .toList(growable: false),
      'markers': state.markers
          .map(
            (marker) => <String, Object?>{
              'markerId': marker.id,
              'label': marker.label,
              'color': marker.color,
              if (marker.atMs != null) 'atMs': marker.atMs,
              if (marker.startMs != null) 'startMs': marker.startMs,
              if (marker.endMs != null) 'endMs': marker.endMs,
            },
          )
          .toList(growable: false),
    });
  }

  /// Returns an independently immutable provider-safe JSON object.
  Map<String, Object?> toProviderJson() => immutableSafeJsonMap(_providerJson);

  String get projectId => _providerJson['projectId']! as String;
  String get projectName => _providerJson['projectName']! as String;
  int get baseRevision => _providerJson['baseRevision']! as int;

  static List<String> _sortedIds(Iterable<String> values) {
    final copied = values.toList(growable: false)..sort();
    return copied;
  }

  static String _safeDisplayLabel(String value, String fallback) {
    final label = value.trim();
    if (label.isEmpty ||
        label.contains('\\') ||
        label.contains('/') ||
        label.contains('://')) {
      return fallback;
    }
    return label;
  }
}
