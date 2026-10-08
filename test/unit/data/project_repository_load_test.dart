import 'dart:convert';
import 'dart:io';

import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle 9 durability: [ProjectRepository.loadFromId] must only return a
/// full, readable document. A missing row, missing file, or corrupt file all
/// return null (the editor shows its "Project not found" screen); it must
/// never fall back to metadata-only content with an empty timeline.
void main() {
  late Directory tempDir;
  late AppDatabase db;
  late ProjectRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clipmind_repo_load_');
    db = AppDatabase(NativeDatabase.memory());
    repository = ProjectRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('loadFromId returns null when no index row exists', () async {
    expect(await repository.loadFromId('absent'), isNull);
  });

  test('loadFromId returns null when the indexed file is missing', () async {
    final project = _project();
    await db.upsertProject(
      project,
      projectPath: '${tempDir.path}/gone.cmproj',
    );

    expect(await repository.loadFromId(project.id), isNull);
  });

  test('loadFromId returns null for a corrupt document', () async {
    final project = _project();
    final path = '${tempDir.path}/${project.id}.cmproj';
    await File(path).writeAsString('{not json');
    await db.upsertProject(project, projectPath: path);

    expect(await repository.loadFromId(project.id), isNull);
  });

  test('loadFromId returns the full document including tracks', () async {
    final project = _project();
    final path = '${tempDir.path}/${project.id}.cmproj';
    await File(path).writeAsString(jsonEncode(project.toJson()));
    await db.upsertProject(project, projectPath: path);

    final loaded = await repository.loadFromId(project.id);
    expect(loaded, isNotNull);
    expect(loaded!.id, project.id);
    expect(loaded.name, project.name);
    expect(loaded.tracks.single.clips.single.id, 'c1');
    expect(loaded.tracks.single.clips.single.sourcePath, '/media/a.mp4');
    expect(loaded.durationMs, 60000);
  });
}

Project _project() {
  final timestamp = DateTime(2026, 10, 8, 9, 30);
  return Project(
    id: 'p1',
    name: 'Loaded',
    createdAt: timestamp,
    updatedAt: timestamp,
    sourceMediaPaths: const ['/media/a.mp4'],
    tracks: const [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'c1',
            trackId: 't1',
            sourcePath: '/media/a.mp4',
            startMs: 0,
            endMs: 60000,
          ),
        ],
      ),
    ],
    durationMs: 60000,
  );
}
