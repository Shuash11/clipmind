import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/thumbnail_service.dart';
import 'package:uuid/uuid.dart';

class ImportVideoResult {
  final bool success;
  final String filePath;
  final VideoMetadata? metadata;
  final String? thumbnailPath;
  final String? error;

  const ImportVideoResult({
    required this.success,
    required this.filePath,
    this.metadata,
    this.thumbnailPath,
    this.error,
  });
}

class ImportVideoUseCase {
  final FfprobeService _ffprobeService;
  final ThumbnailService _thumbnailService;
  final Uuid _uuid;

  ImportVideoUseCase(this._ffprobeService, this._thumbnailService)
    : _uuid = const Uuid();

  Future<ImportVideoResult> execute(String filePath, {Project? project}) async {
    final metadata = await _ffprobeService.extractMetadata(filePath);
    if (metadata == null) {
      return ImportVideoResult(
        success: false,
        filePath: filePath,
        error: 'Could not read video metadata',
      );
    }

    final thumbnail = await _thumbnailService.generate(filePath);

    return ImportVideoResult(
      success: true,
      filePath: filePath,
      metadata: metadata,
      thumbnailPath: thumbnail,
    );
  }

  Clip createClipFromResult(
    String filePath,
    VideoMetadata metadata, {
    required String trackId,
    int positionMs = 0,
  }) {
    return Clip(
      id: _uuid.v4(),
      trackId: trackId,
      sourcePath: filePath,
      startMs: 0,
      endMs: metadata.durationMs,
      positionMs: positionMs,
      label: filePath.split(RegExp(r'[/\\]')).last,
    );
  }

  Project addClipToProject(Project project, Clip clip) {
    final videoTrackIndex = project.tracks.indexWhere(
      (t) => t.type == TrackType.video,
    );

    final updatedTracks = List<Track>.from(project.tracks);

    if (videoTrackIndex >= 0) {
      final track = updatedTracks[videoTrackIndex];
      updatedTracks[videoTrackIndex] = track.copyWith(
        clips: [...track.clips, clip],
      );
    } else {
      updatedTracks.add(
        Track(
          id: _uuid.v4(),
          type: TrackType.video,
          label: 'Video',
          clips: [clip],
        ),
      );
    }

    return project.copyWith(
      tracks: updatedTracks,
      sourceMediaPaths: [...project.sourceMediaPaths, clip.sourcePath],
      thumbnailPath: project.thumbnailPath ?? clip.sourcePath,
      updatedAt: DateTime.now(),
    );
  }
}
