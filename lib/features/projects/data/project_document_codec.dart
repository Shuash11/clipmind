import 'dart:convert';

import 'package:clipmind/core/results/result.dart';

import '../domain/entities/project_document.dart';
import '../domain/entities/persisted_transaction_record.dart';
import '../domain/entities/project_state_snapshot.dart';

abstract interface class ProjectDocumentValidator {
  Result<void> validateJson(String json);
}

final class ProjectDocumentCodec implements ProjectDocumentValidator {
  static const int currentSchemaVersion = 2;

  String encodeJson(ProjectDocument document) => jsonEncode({
    'schemaVersion': document.schemaVersion,
    'id': document.id,
    'name': document.name,
    'createdAt': document.createdAt.toIso8601String(),
    'updatedAt': document.updatedAt.toIso8601String(),
    'outputDirectory': document.outputDirectory,
    'currentState': document.currentState.toJson(),
    'revision': document.revision,
    'history': document.history.map((record) => record.toJson()).toList(),
    'historyCursor': document.historyCursor,
  });

  Result<ProjectDocument> decodeJson(String source) {
    try {
      final json = Map<String, Object?>.from(jsonDecode(source) as Map);
      if (json['schemaVersion'] != currentSchemaVersion) {
        return const Failure(ProjectPersistenceFailure('Unsupported schema'));
      }
      return Success(
        ProjectDocument(
          schemaVersion: json['schemaVersion'] as int,
          id: json['id'] as String,
          name: json['name'] as String,
          createdAt: DateTime.parse(json['createdAt'] as String),
          updatedAt: DateTime.parse(json['updatedAt'] as String),
          outputDirectory: json['outputDirectory'] as String,
          currentState: ProjectStateSnapshot.fromJson(
            Map<String, Object?>.from(json['currentState'] as Map),
          ),
          revision: json['revision'] as int,
          history: (json['history'] as List<Object?>? ?? const [])
              .map(
                (value) => PersistedTransactionRecord.fromJson(
                  Map<String, Object?>.from(value as Map),
                ),
              )
              .toList(),
          historyCursor: json['historyCursor'] as int,
        ),
      );
    } catch (error) {
      return Failure(ProjectPersistenceFailure('Invalid project JSON: $error'));
    }
  }

  @override
  Result<void> validateJson(String json) {
    final decoded = decodeJson(json);
    if (decoded case Success<ProjectDocument>()) return const Success(null);
    final failure = decoded as Failure<ProjectDocument>;
    return Failure(failure.error);
  }
}
