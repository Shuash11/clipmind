import 'value_utils.dart';

final class MediaAsset {
  MediaAsset({
    required this.id,
    required this.sourcePath,
    required this.displayName,
    required this.durationMs,
    Set<String> tagIds = const {},
  }) : tagIds = Set.unmodifiable(tagIds);

  final String id;
  final String sourcePath;
  final String displayName;
  final int durationMs;
  final Set<String> tagIds;

  MediaAsset copyWith({Set<String>? tagIds}) => MediaAsset(
    id: id,
    sourcePath: sourcePath,
    displayName: displayName,
    durationMs: durationMs,
    tagIds: tagIds ?? this.tagIds,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'sourcePath': sourcePath,
    'displayName': displayName,
    'durationMs': durationMs,
    'tagIds': tagIds.toList(),
  };

  factory MediaAsset.fromJson(Map<String, Object?> json) => MediaAsset(
    id: json['id'] as String,
    sourcePath: json['sourcePath'] as String,
    displayName: json['displayName'] as String,
    durationMs: json['durationMs'] as int,
    tagIds: Set<String>.from(
      (json['tagIds'] as List<Object?>? ?? const []).cast<String>(),
    ),
  );

  @override
  bool operator ==(Object other) =>
      other is MediaAsset &&
      id == other.id &&
      sourcePath == other.sourcePath &&
      displayName == other.displayName &&
      durationMs == other.durationMs &&
      setEquals(tagIds, other.tagIds);

  @override
  int get hashCode =>
      Object.hash(id, sourcePath, displayName, durationMs, setHash(tagIds));
}
