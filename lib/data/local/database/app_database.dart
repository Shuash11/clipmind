import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:clipmind/data/models/project.dart' as models;
import 'package:clipmind/data/models/chat_message.dart' as chat_models;
import 'package:clipmind/data/models/edit_operation.dart' as edit_models;

part 'app_database.g.dart';

@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get projectPath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get durationMs => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get sourceMediaPaths => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChatMessageRow')
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  IntColumn get timestamp => integer()();
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class EditHistory extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get operationType => text()();
  TextColumn get params => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Projects, ChatMessages, EditHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  // Project DAOs

  Future<void> upsertProject(
    models.Project project, {
    String projectPath = '',
  }) async {
    await into(projects).insertOnConflictUpdate(
      ProjectRow(
        id: project.id,
        name: project.name,
        projectPath: projectPath,
        thumbnailPath: project.thumbnailPath,
        durationMs: project.durationMs,
        createdAt: project.createdAt.millisecondsSinceEpoch,
        updatedAt: project.updatedAt.millisecondsSinceEpoch,
        sourceMediaPaths: jsonEncode(project.sourceMediaPaths),
      ),
    );
  }

  Future<models.Project?> getProject(String id) async {
    final row = await (select(
      projects,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _projectRowToModel(row);
  }

  Future<List<models.Project>> listRecentProjects({int limit = 20}) async {
    final rows =
        await (select(projects)
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .get();
    return rows.map(_projectRowToModel).toList();
  }

  Future<void> deleteProject(String id) async {
    await (delete(projects)..where((t) => t.id.equals(id))).go();
  }

  Future<String?> getProjectPath(String id) async {
    final row = await (select(
      projects,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.projectPath;
  }

  // Chat Message DAOs

  Future<void> saveChatMessage(
    String projectId,
    chat_models.ChatMessage msg,
  ) async {
    await into(chatMessages).insertOnConflictUpdate(
      ChatMessageRow(
        id: msg.id,
        projectId: projectId,
        role: msg.role.name,
        content: msg.content,
        timestamp: msg.timestamp.millisecondsSinceEpoch,
        status: msg.status.name,
      ),
    );
  }

  Future<List<chat_models.ChatMessage>> getChatMessages(
    String projectId,
  ) async {
    final rows =
        await (select(chatMessages)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.timestamp,
                  mode: OrderingMode.asc,
                ),
              ]))
            .get();
    return rows.map(_chatMessageRowToModel).toList();
  }

  Future<void> deleteChatMessages(String projectId) async {
    await (delete(
      chatMessages,
    )..where((t) => t.projectId.equals(projectId))).go();
  }

  // Edit History DAOs

  Future<void> saveEditOperation(
    String projectId,
    edit_models.EditOperation op,
  ) async {
    await into(editHistory).insertOnConflictUpdate(
      EditHistoryData(
        id: op.id,
        projectId: projectId,
        operationType: op.type.name,
        params: jsonEncode(op.params),
        createdAt: op.createdAt.millisecondsSinceEpoch,
      ),
    );
  }

  Future<List<edit_models.EditOperation>> getEditHistory(
    String projectId,
  ) async {
    final rows =
        await (select(editHistory)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.asc,
                ),
              ]))
            .get();
    return rows.map(_editHistoryRowToModel).toList();
  }

  Future<void> deleteEditHistory(String projectId) async {
    await (delete(
      editHistory,
    )..where((t) => t.projectId.equals(projectId))).go();
  }

  // Conversion helpers

  models.Project _projectRowToModel(ProjectRow row) {
    return models.Project(
      id: row.id,
      name: row.name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      sourceMediaPaths: row.sourceMediaPaths.isNotEmpty
          ? List<String>.from(jsonDecode(row.sourceMediaPaths))
          : [],
      durationMs: row.durationMs,
      thumbnailPath: row.thumbnailPath,
    );
  }

  chat_models.ChatMessage _chatMessageRowToModel(ChatMessageRow row) {
    return chat_models.ChatMessage(
      id: row.id,
      role: chat_models.ChatRole.values.firstWhere((r) => r.name == row.role),
      content: row.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row.timestamp),
      status: chat_models.MessageStatus.values.firstWhere(
        (s) => s.name == row.status,
      ),
    );
  }

  edit_models.EditOperation _editHistoryRowToModel(EditHistoryData row) {
    return edit_models.EditOperation(
      id: row.id,
      type: edit_models.EditOperationType.values.firstWhere(
        (t) => t.name == row.operationType,
      ),
      params: row.params.isNotEmpty
          ? Map<String, dynamic>.from(jsonDecode(row.params))
          : {},
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/clipmind.db');
    return NativeDatabase(file);
  });
}
