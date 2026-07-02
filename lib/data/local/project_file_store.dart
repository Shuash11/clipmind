import 'dart:convert';
import 'dart:io';
import 'package:clipmind/data/models/project.dart';

class ProjectFileStore {
  Future<bool> write(Project project, String directory) async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('$directory/${project.id}.cmproj');
      await file.writeAsString(jsonEncode(project.toJson()));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Project?> read(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return Project.fromJson(json as Map<String, dynamic>);
    } catch (_) {
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
    } catch (_) {
      return [];
    }
  }

  Future<bool> export(Project project, String path, String format) async {
    try {
      final exportDir = Directory(path);
      if (!await exportDir.exists()) await exportDir.create(recursive: true);
      final sanitizedName = project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final fileName = '${sanitizedName}_${project.id.substring(0, 8)}';
      final file = File('${exportDir.path}/$fileName.cmproj');
      final exportData = {
        ...project.toJson(),
        'exportFormat': format,
        'exportedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(exportData));
      return true;
    } catch (_) {
      return false;
    }
  }
}
