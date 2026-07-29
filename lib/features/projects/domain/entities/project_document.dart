import 'persisted_transaction_record.dart';
import 'project_state_snapshot.dart';
import 'value_utils.dart';

final class ProjectDocument {
  ProjectDocument({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.outputDirectory,
    required this.currentState,
    required this.revision,
    required List<PersistedTransactionRecord> history,
    required this.historyCursor,
  }) : history = List.unmodifiable(history);

  final int schemaVersion;
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String outputDirectory;
  final ProjectStateSnapshot currentState;
  final int revision;
  final List<PersistedTransactionRecord> history;
  final int historyCursor;
  ProjectDocument copyWith({
    ProjectStateSnapshot? currentState,
    int? revision,
    List<PersistedTransactionRecord>? history,
    int? historyCursor,
    DateTime? updatedAt,
  }) => ProjectDocument(
    schemaVersion: schemaVersion,
    id: id,
    name: name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    outputDirectory: outputDirectory,
    currentState: currentState ?? this.currentState,
    revision: revision ?? this.revision,
    history: history ?? this.history,
    historyCursor: historyCursor ?? this.historyCursor,
  );

  @override
  bool operator ==(Object other) =>
      other is ProjectDocument &&
      schemaVersion == other.schemaVersion &&
      id == other.id &&
      name == other.name &&
      createdAt == other.createdAt &&
      updatedAt == other.updatedAt &&
      outputDirectory == other.outputDirectory &&
      currentState == other.currentState &&
      revision == other.revision &&
      listEquals(history, other.history) &&
      historyCursor == other.historyCursor;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    id,
    name,
    createdAt,
    updatedAt,
    outputDirectory,
    currentState,
    revision,
    listHash(history),
    historyCursor,
  );
}
