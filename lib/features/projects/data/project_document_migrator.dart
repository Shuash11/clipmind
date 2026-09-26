import 'dart:convert';

import 'package:clipmind/core/results/result.dart';

import '../domain/entities/clip_transform.dart';
import '../domain/entities/media_asset.dart';
import '../domain/entities/project_clip.dart';
import '../domain/entities/project_document.dart';
import '../domain/entities/project_state_snapshot.dart';
import '../domain/entities/project_track.dart';
import 'project_document_codec.dart';

final class ProjectDocumentMigrator implements ProjectDocumentValidator {
  const ProjectDocumentMigrator(this._codec);
  final ProjectDocumentCodec _codec;

  Result<ProjectDocument> migrateJson(String source) {
    final direct = _codec.decodeJson(source);
    if (direct case Success<ProjectDocument>()) return direct;
    try {
      final json = Map<String, Object?>.from(jsonDecode(source) as Map);
      final schema = json['schemaVersion'] as int? ?? 0;
      if (schema > 1) {
        return const Failure(
          ProjectPersistenceFailure('Unsupported project schema'),
        );
      }
      final id = json['id'] as String;
      final paths = <String>{
        ...((json['sourceMediaPaths'] as List<Object?>? ?? const [])
            .cast<String>()),
      };
      final tracksJson = (json['tracks'] as List<Object?>? ?? const []);
      for (final rawTrack in tracksJson) {
        for (final rawClip
            in ((rawTrack as Map)['clips'] as List<Object?>? ?? const [])) {
          final path = (rawClip as Map)['sourcePath'] as String?;
          if (path != null) paths.add(path);
        }
      }
      final assetsByPath = <String, MediaAsset>{};
      for (final path in paths) {
        final assetId =
            'asset-${_stableHash('$id|${path.replaceAll('\\', '/').toLowerCase()}')}';
        assetsByPath[path] = MediaAsset(
          id: assetId,
          sourcePath: path,
          displayName: path.split(RegExp(r'[/\\]')).last,
          durationMs: 0,
        );
      }
      final tracks = tracksJson.map((rawTrack) {
        final track = Map<String, Object?>.from(rawTrack as Map);
        final trackId = track['id'] as String;
        final clips = (track['clips'] as List<Object?>? ?? const []).map((
          rawClip,
        ) {
          final clip = Map<String, Object?>.from(rawClip as Map);
          final sourcePath = clip['sourcePath'] as String;
          final start = clip['startMs'] as int;
          final end = clip['endMs'] as int;
          return ProjectClip(
            id: clip['id'] as String,
            assetId: assetsByPath[sourcePath]!.id,
            trackId: trackId,
            startMs: start,
            endMs: end,
            positionMs: clip['positionMs'] as int? ?? 0,
            tagIds: const {},
            transform: const ClipTransform(
              width: 1920,
              height: 1080,
              fit: ClipFit.contain,
              rotationDegrees: 0,
            ),
            speed: 1,
            muted: clip['muted'] as bool? ?? false,
            volume: 1,
          );
        }).toList();
        return ProjectTrack(
          id: trackId,
          kind: ProjectTrackKind.values.byName(
            (track['type'] as String? ?? 'video'),
          ),
          clips: clips,
        );
      }).toList();
      return Success(
        ProjectDocument(
          schemaVersion: 2,
          id: id,
          name: json['name'] as String,
          createdAt: DateTime.parse(json['createdAt'] as String),
          updatedAt: DateTime.parse(json['updatedAt'] as String),
          outputDirectory: (json['outputDir'] ?? '') as String,
          currentState: ProjectStateSnapshot(
            assets: assetsByPath.values.toList(),
            tracks: tracks,
            tags: const [],
            markers: const [],
            overlays: const [],
          ),
          revision: 0,
          history: const [],
          historyCursor: -1,
        ),
      );
    } catch (error) {
      return Failure(
        ProjectPersistenceFailure('Unable to migrate project: $error'),
      );
    }
  }

  @override
  Result<void> validateJson(String json) {
    final result = migrateJson(json);
    if (result case Success<ProjectDocument>()) return const Success(null);
    final failure = result as Failure<ProjectDocument>;
    return Failure(failure.error);
  }

  String _stableHash(String value) {
    var hash = 2166136261;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
