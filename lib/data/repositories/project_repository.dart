import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/local/project_file_store.dart';
import 'package:path_provider/path_provider.dart';

class ProjectRepository {
  final AppDatabase _db;
  final ProjectFileStore _fileStore;
  final _uuid = const Uuid();

  ProjectRepository(this._db) : _fileStore = ProjectFileStore();

  Future<Project> createNew(
    String name, {
    List<String> sourceMediaPaths = const [],
    int durationMs = 0,
    String? thumbnailPath,
  }) async {
    final now = DateTime.now();
    final project = Project(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
      sourceMediaPaths: sourceMediaPaths,
      tracks: _buildInitialTracks(sourceMediaPaths, durationMs),
      durationMs: durationMs,
      thumbnailPath: thumbnailPath,
    );
    await save(project);
    return project;
  }

  Future<void> save(Project project) async {
    final dir = await _getProjectsDir();
    final projectPath = '${dir.path}/${project.id}.cmproj';
    await _fileStore.write(project, dir.path);
    await _db.upsertProject(project, projectPath: projectPath);
  }

  Future<Project?> load(String path) async {
    return _fileStore.read(path);
  }

  Future<Project?> loadFromId(String id) async {
    final path = await _db.getProjectPath(id);
    if (path == null) return null;
    final project = await _fileStore.read(path);
    if (project != null) return project;
    final meta = await _db.getProject(id);
    return meta;
  }

  Future<List<Project>> listRecent() async {
    return _db.listRecentProjects();
  }

  Future<void> delete(String id) async {
    final path = await _db.getProjectPath(id);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _db.deleteProject(id);
  }

  Future<Directory> _getProjectsDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/projects');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  List<Track> _buildInitialTracks(
    List<String> sourceMediaPaths,
    int durationMs,
  ) {
    if (sourceMediaPaths.isEmpty) return const [];

    final trackId = _uuid.v4();
    final sourcePath = sourceMediaPaths.first;
    return [
      Track(
        id: trackId,
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: _uuid.v4(),
            trackId: trackId,
            sourcePath: sourcePath,
            startMs: 0,
            endMs: durationMs,
            positionMs: 0,
            label: _fileNameFromPath(sourcePath),
          ),
        ],
      ),
    ];
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last.trim();
    return name.isEmpty ? 'Untitled video' : name;
  }
}
