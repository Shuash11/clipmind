import 'package:clipmind/core/results/result.dart';

import '../entities/clip_transform.dart';
import '../entities/media_asset.dart';
import '../entities/project_clip.dart';
import '../entities/project_document.dart';
import '../ids/id_generator.dart';

final class ProjectImportService {
  const ProjectImportService(this._ids);

  final IdGenerator _ids;

  Result<ProjectDocument> addLocalMedia(
    ProjectDocument document, {
    required String sourcePath,
    required String trackId,
    required int durationMs,
  }) {
    final trackIndex = document.currentState.tracks.indexWhere(
      (track) => track.id == trackId,
    );
    if (trackIndex < 0 || sourcePath.isEmpty || durationMs <= 0) {
      return const Failure(ProjectValidationFailure('Invalid import target'));
    }
    final asset = MediaAsset(
      id: _ids.next(),
      sourcePath: sourcePath,
      displayName: sourcePath.split(RegExp(r'[/\\]')).last,
      durationMs: durationMs,
    );
    final tracks = [...document.currentState.tracks];
    final track = tracks[trackIndex];
    final positionMs = track.clips.fold<int>(
      0,
      (latest, clip) => latest > clip.positionMs + clip.durationMs
          ? latest
          : clip.positionMs + clip.durationMs,
    );
    final clip = ProjectClip(
      id: _ids.next(),
      assetId: asset.id,
      trackId: trackId,
      startMs: 0,
      endMs: durationMs,
      positionMs: positionMs,
      tagIds: const {},
      transform: const ClipTransform(
        width: 1920,
        height: 1080,
        fit: ClipFit.contain,
        rotationDegrees: 0,
      ),
      speed: 1,
      muted: false,
      volume: 1,
    );
    tracks[trackIndex] = track.copyWith(clips: [...track.clips, clip]);
    return Success(
      document.copyWith(
        currentState: document.currentState.copyWith(
          assets: [...document.currentState.assets, asset],
          tracks: tracks,
        ),
      ),
    );
  }
}
