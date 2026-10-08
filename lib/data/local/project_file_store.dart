import 'dart:convert';
import 'dart:io';
import 'package:clipmind/core/errors/failures.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:flutter/foundation.dart';

class ProjectFileStore {
  /// Persists [project] as `<directory>/<id>.cmproj`.
  ///
  /// The JSON is flushed to a sibling `.tmp` file first and then renamed over
  /// the target (same directory, so same volume): an existing document stays
  /// intact until the new one is completely on disk. Throws
  /// [PersistenceFailure] when the document cannot be written, after a
  /// best-effort removal of the temporary file.
  Future<void> write(Project project, String directory) async {
    final target = '$directory/${project.id}.cmproj';
    final tmp = '$target.tmp';
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) await dir.create(recursive: true);
      await File(tmp).writeAsString(jsonEncode(project.toJson()), flush: true);
      await File(tmp).rename(target);
    } catch (e) {
      await _removeTempFileQuietly(tmp);
      throw PersistenceFailure('The project could not be saved to disk.', e);
    }
  }

  Future<void> _removeTempFileQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best effort only: the next successful write overwrites the temp file.
    }
  }

  Future<Project?> read(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return Project.fromJson(json as Map<String, dynamic>);
    } catch (e, s) {
      debugPrint('ProjectFileStore error: $e\n$s');
      return null;
    }
  }

  Future<List<Project>> list(String directory) async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) return [];
      final entities = await dir.list().toList();
      final results = <Project>[];
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.cmproj')) {
          final project = await read(entity.path);
          if (project != null) results.add(project);
        }
      }
      results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return results;
    } catch (e, s) {
      debugPrint('ProjectFileStore error: $e\n$s');
      return [];
    }
  }

  Future<bool> export(Project project, String path, String format) async {
    try {
      final exportDir = Directory(path);
      if (!await exportDir.exists()) await exportDir.create(recursive: true);
      final sanitizedName = project.name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim();
      final fileName = '${sanitizedName}_${project.id.substring(0, 8)}';
      final file = File('${exportDir.path}/$fileName.cmproj');
      final exportData = {
        ...project.toJson(),
        'exportFormat': format,
        'exportedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(exportData));
      return true;
    } catch (e, s) {
      debugPrint('ProjectFileStore error: $e\n$s');
      return false;
    }
  }
}
