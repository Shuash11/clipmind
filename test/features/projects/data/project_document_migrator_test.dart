import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/data/project_document_codec.dart';
import 'package:clipmind/features/projects/data/project_document_migrator.dart';
import 'package:clipmind/features/projects/domain/entities/media_asset.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';

String fixture(String name) =>
    File('test/fixtures/projects/$name').readAsStringSync();

void main() {
  final migrator = ProjectDocumentMigrator(ProjectDocumentCodec());

  test(
    'v0 sourcePath migration retains track, clip, and deterministic asset',
    () {
      final result = migrator.migrateJson(
        fixture('legacy_v0_source_paths.cmproj'),
      );
      final document = (result as Success<ProjectDocument>).value;
      expect(document.schemaVersion, 2);
      expect(
        document.currentState.assets.single.sourcePath,
        r'C:\media\legacy-v0.mp4',
      );
      expect(
        document.currentState.tracks.single.clips.single.assetId,
        document.currentState.assets.single.id,
      );
      expect(document.currentState.tags, isEmpty);
      expect(document.currentState.markers, isEmpty);
      expect(document.currentState.overlays, isEmpty);
    },
  );

  test('v1 sourceMediaPaths migration retains legacy media mapping', () {
    final document =
        (migrator.migrateJson(fixture('legacy_v1_source_media_paths.cmproj'))
                as Success<ProjectDocument>)
            .value;
    expect(
      document.currentState.assets.map((MediaAsset asset) => asset.sourcePath),
      [r'C:\media\legacy-v1.mp4'],
    );
    expect(
      document.currentState.tracks.single.clips.single.id,
      'legacy-clip-v1',
    );
  });

  test(
    'asset IDs are deterministic for the same legacy project and Windows path',
    () {
      final first =
          (migrator.migrateJson(fixture('legacy_v1_source_media_paths.cmproj'))
                  as Success<ProjectDocument>)
              .value;
      final second =
          (migrator.migrateJson(fixture('legacy_v1_source_media_paths.cmproj'))
                  as Success<ProjectDocument>)
              .value;
      expect(
        first.currentState.assets.single.id,
        second.currentState.assets.single.id,
      );
    },
  );

  test('schema version two input is idempotent', () {
    final migrated =
        (migrator.migrateJson(fixture('legacy_v1_source_media_paths.cmproj'))
                as Success<ProjectDocument>)
            .value;
    final json = ProjectDocumentCodec().encodeJson(migrated);
    expect(
      (migrator.migrateJson(json) as Success<ProjectDocument>).value,
      migrated,
    );
  });
}
