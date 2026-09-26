import '../entities/project_state_snapshot.dart';

import '../entities/project_clip.dart';

enum TransactionSourceKind { agent, manual }

abstract base class ProjectCommand {
  const ProjectCommand();
  String get type;
}

final class CanonicalCommandSummary {
  CanonicalCommandSummary({required this.type, required List<String> targetIds})
    : targetIds = List.unmodifiable(targetIds);

  final String type;
  final List<String> targetIds;

  Map<String, Object?> toJson() => {'type': type, 'targetIds': targetIds};

  factory CanonicalCommandSummary.fromJson(Map<String, Object?> json) =>
      CanonicalCommandSummary(
        type: json['type'] as String,
        targetIds: List<String>.from(json['targetIds'] as List),
      );

  @override
  bool operator ==(Object other) =>
      other is CanonicalCommandSummary &&
      type == other.type &&
      _same(targetIds, other.targetIds);

  @override
  int get hashCode => Object.hash(type, Object.hashAll(targetIds));
}

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

final class CommandExecution {
  CommandExecution({
    required this.candidateState,
    required List<CanonicalCommandSummary> summaries,
  }) : summaries = List.unmodifiable(summaries);

  final ProjectStateSnapshot candidateState;
  final List<CanonicalCommandSummary> summaries;
}

ProjectClip? findClip(ProjectStateSnapshot state, String clipId) {
  for (final track in state.tracks) {
    for (final clip in track.clips) {
      if (clip.id == clipId) return clip;
    }
  }
  return null;
}
