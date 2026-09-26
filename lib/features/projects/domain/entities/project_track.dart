import 'project_clip.dart';
import 'value_utils.dart';

enum ProjectTrackKind { video, audio, text, fx }

final class ProjectTrack {
  ProjectTrack({
    required this.id,
    required this.kind,
    required List<ProjectClip> clips,
  }) : clips = List.unmodifiable(clips);

  final String id;
  final ProjectTrackKind kind;
  final List<ProjectClip> clips;

  ProjectTrack copyWith({List<ProjectClip>? clips}) =>
      ProjectTrack(id: id, kind: kind, clips: clips ?? this.clips);

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'clips': clips.map((clip) => clip.toJson()).toList(),
  };

  factory ProjectTrack.fromJson(Map<String, Object?> json) => ProjectTrack(
    id: json['id'] as String,
    kind: ProjectTrackKind.values.byName(json['kind'] as String),
    clips: (json['clips'] as List<Object?>? ?? const [])
        .map(
          (value) =>
              ProjectClip.fromJson(Map<String, Object?>.from(value as Map)),
        )
        .toList(),
  );

  @override
  bool operator ==(Object other) =>
      other is ProjectTrack &&
      id == other.id &&
      kind == other.kind &&
      listEquals(clips, other.clips);

  @override
  int get hashCode => Object.hash(id, kind, listHash(clips));
}
