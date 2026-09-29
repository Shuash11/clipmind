import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';

/// The selected timeline clip id, shared between [TimelineView] (the
/// writer, on select/delete/copy) and the CapCut-style left panel (the
/// reader, for the effects/text/sound targets). null = no selection.
///
/// Stale ids degrade gracefully: the panel resolves the id against the
/// open project and shows its select-a-clip state when unknown.
final selectedClipIdProvider = StateProvider<String?>((ref) => null);

/// The project clip for [clipId] (searched across all tracks), or null.
Clip? resolveSelectedClip(Project? project, String? clipId) {
  if (project == null || clipId == null) return null;
  for (final track in project.tracks) {
    for (final clip in track.clips) {
      if (clip.id == clipId) return clip;
    }
  }
  return null;
}

/// The clip's display label (its label, else the file name) — the
/// timeline convention.
String clipDisplayLabel(Clip clip) {
  final label = clip.label;
  if (label != null && label.trim().isNotEmpty) return label;
  final normalized = clip.sourcePath.replaceAll('\\', '/');
  final name = normalized.split('/').last.trim();
  return name.isEmpty ? 'clip' : name;
}
