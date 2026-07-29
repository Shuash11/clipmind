// The public dependency names intentionally map to private stored fields.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:clipmind/core/results/result.dart';

import '../domain/entities/project_document.dart';
import '../domain/repositories/project_repository.dart';
import '../domain/transactions/project_save_outcome.dart';
import 'atomic_project_file_store.dart';
import 'project_document_codec.dart';
import 'project_document_migrator.dart';

final class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl({
    required AtomicProjectFileStore fileStore,
    required ProjectDocumentCodec codec,
    required ProjectIndex index,
    required String Function(ProjectDocument document) pathFor,
    ProjectDocumentMigrator? migrator,
  }) : _fileStore = fileStore,
       _codec = codec,
       _index = index,
       _pathFor = pathFor,
       _migrator = migrator ?? ProjectDocumentMigrator(codec);

  final AtomicProjectFileStore _fileStore;
  final ProjectDocumentCodec _codec;
  final ProjectIndex _index;
  final String Function(ProjectDocument document) _pathFor;
  final ProjectDocumentMigrator _migrator;
  @override
  Future<Result<ProjectSaveOutcome>> save(ProjectDocument candidate) async {
    final fileResult = await _fileStore.writeJson(
      _pathFor(candidate),
      _codec.encodeJson(candidate),
    );
    if (fileResult case Failure<ProjectFileWriteOutcome>(:final error)) {
      return Failure(error);
    }
    final warnings = <ProjectSaveWarning>[];
    final fileWarning =
        (fileResult as Success<ProjectFileWriteOutcome>).value.warning;
    if (fileWarning != null) warnings.add(fileWarning);
    try {
      await _index.upsert(candidate);
    } catch (_) {
      warnings.add(
        const ProjectIndexWarning(
          'project_index_upsert_failed',
          'Drift upsert failed',
        ),
      );
    }
    return Success(ProjectSaveOutcome(document: candidate, warnings: warnings));
  }

  @override
  Future<Result<ProjectSaveOutcome>> load(String path) async {
    final recovered = await _fileStore.recover(
      path,
      validatorOverride: _migrator,
    );
    if (recovered case Failure<ProjectReadResult>(:final error)) {
      return Failure(error);
    }
    final readOutcome = (recovered as Success<ProjectReadResult>).value;
    final direct = _codec.decodeJson(readOutcome.json);
    final warnings = <ProjectSaveWarning>[...readOutcome.warnings];
    late final ProjectDocument document;
    if (direct is Success<ProjectDocument>) {
      document = direct.value;
    } else {
      final migrated = _migrator.migrateJson(readOutcome.json);
      if (migrated case Failure<ProjectDocument>(:final error)) {
        return Failure(error);
      }
      document = (migrated as Success<ProjectDocument>).value;
      final migrationSchema = _legacySchema(readOutcome.json);
      final write = await _fileStore.writeJson(
        path,
        _codec.encodeJson(document),
        migrationFromSchema: migrationSchema,
      );
      if (write case Failure<ProjectFileWriteOutcome>(:final error)) {
        return Failure(error);
      }
      final warning = (write as Success<ProjectFileWriteOutcome>).value.warning;
      if (warning != null) warnings.add(warning);
    }
    try {
      await _index.upsert(document);
    } catch (_) {
      warnings.add(
        const ProjectIndexWarning(
          'project_index_upsert_failed',
          'Drift upsert failed',
        ),
      );
    }
    return Success(ProjectSaveOutcome(document: document, warnings: warnings));
  }

  int _legacySchema(String json) {
    try {
      final decoded = Map<String, Object?>.from(jsonDecode(json) as Map);
      return decoded['schemaVersion'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
