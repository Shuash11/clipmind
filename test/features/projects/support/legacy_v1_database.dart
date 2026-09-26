// This fixture exposes a public directory parameter while storing it privately.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// A file-backed v1 database that can be reopened by the application database.
final class LegacyV1ProjectIndexFixture {
  const LegacyV1ProjectIndexFixture({
    required this.executor,
    required Directory directory,
  }) : _directory = directory;

  final QueryExecutor executor;
  final Directory _directory;

  Future<void> dispose() => _directory.delete(recursive: true);
}

/// Builds a real pre-v2 Drift schema and closes it before it is reopened.
Future<LegacyV1ProjectIndexFixture> legacyV1ProjectIndexFixture() async {
  final directory = await Directory.systemTemp.createTemp('clipmind-v1-');
  final file = File(
    '${directory.path}${Platform.pathSeparator}project-index.sqlite',
  );
  final seedingExecutor = NativeDatabase(file);

  try {
    try {
      await seedingExecutor.ensureOpen(_LegacyV1Seeder());
    } finally {
      await seedingExecutor.close();
    }
    return LegacyV1ProjectIndexFixture(
      executor: NativeDatabase(file),
      directory: directory,
    );
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
}

final class _LegacyV1Seeder implements QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails _) async {
    await executor.ensureOpen(this);
    await executor.runCustom('''
      CREATE TABLE projects (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        project_path TEXT NOT NULL,
        thumbnail_path TEXT NULL,
        duration_ms INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        source_media_paths TEXT NOT NULL
      )
    ''');
    await executor.runCustom('''
      CREATE TABLE chat_messages (
        id TEXT NOT NULL PRIMARY KEY,
        project_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT NOT NULL
      )
    ''');
    await executor.runCustom('''
      CREATE TABLE edit_history (
        id TEXT NOT NULL PRIMARY KEY,
        project_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        params TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await executor.runCustom('''
      INSERT INTO projects (
        id,
        name,
        project_path,
        thumbnail_path,
        duration_ms,
        created_at,
        updated_at,
        source_media_paths
      ) VALUES (
        'project-1',
        'Existing',
        'C:\\projects\\project-1.cmproj',
        NULL,
        1000,
        0,
        0,
        '["C:\\\\media\\\\source.mp4"]'
      )
    ''');
  }
}
