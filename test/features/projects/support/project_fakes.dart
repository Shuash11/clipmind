import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/data/project_file_io.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/ids/id_generator.dart';
import 'package:clipmind/features/projects/domain/repositories/project_document_locator.dart';
import 'package:clipmind/features/projects/domain/repositories/project_repository.dart';
import 'package:clipmind/features/projects/domain/services/project_render_input_resolver.dart';
import 'package:clipmind/features/projects/domain/transactions/edit_transaction.dart';
import 'package:clipmind/features/projects/domain/transactions/project_document_publisher.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:clipmind/features/projects/domain/transactions/project_transaction_gateway.dart';

final class SequenceIdGenerator implements IdGenerator {
  SequenceIdGenerator(Iterable<String> values) : _values = values.iterator;

  final Iterator<String> _values;

  @override
  String next() {
    if (!_values.moveNext()) throw StateError('No deterministic ID remains');
    return _values.current;
  }
}

enum FileIoFailure { flush, copy, targetToRollback, promote, restore, cleanup }

final class MemoryProjectFileIo implements ProjectFileIo {
  MemoryProjectFileIo([Map<String, String>? initial]) : files = {...?initial};
  final Map<String, String> files;
  final Set<FileIoFailure> failurePoints = <FileIoFailure>{};
  final List<String> operations = [];

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<String> read(String path) async => files[path]!;

  @override
  Future<void> writeAndFlush(String path, String content) async {
    operations.add('write:$path');
    if (failurePoints.contains(FileIoFailure.flush)) {
      throw StateError('flush failed');
    }
    files[path] = content;
  }

  @override
  Future<void> copy(String from, String to) async {
    operations.add('copy:$from:$to');
    if (failurePoints.contains(FileIoFailure.copy)) {
      throw StateError('copy failed');
    }
    files[to] = files[from]!;
  }

  @override
  Future<void> rename(String from, String to) async {
    operations.add('rename:$from:$to');
    if (from.endsWith('.tmp') &&
        failurePoints.contains(FileIoFailure.promote)) {
      throw StateError('promote failed');
    }
    if (from.endsWith('.rollback') &&
        to.endsWith('.cmproj') &&
        failurePoints.contains(FileIoFailure.restore)) {
      throw StateError('restore failed');
    }
    if (to.endsWith('.rollback') &&
        failurePoints.contains(FileIoFailure.targetToRollback)) {
      throw StateError('rollback move failed');
    }
    files[to] = files.remove(from)!;
  }

  @override
  Future<void> delete(String path) async {
    operations.add('delete:$path');
    if (failurePoints.contains(FileIoFailure.cleanup)) {
      throw StateError('cleanup failed');
    }
    files.remove(path);
  }
}

final class FakeProjectIndex implements ProjectIndex {
  bool failUpsert = false;
  int upsertCalls = 0;
  final Map<String, ProjectDocument> documents = {};
  @override
  Future<void> upsert(ProjectDocument document) async {
    upsertCalls++;
    if (failUpsert) throw StateError('index unavailable');
    documents[document.id] = document;
  }

  @override
  Future<void> clear() async => documents.clear();

  @override
  Future<List<String>> projectPaths() async => documents.keys.toList();
}

final class RecordingProjectRepository implements ProjectRepository {
  RecordingProjectRepository(this.document);
  ProjectDocument document;
  bool failSave = false;
  List<ProjectSaveWarning> nextWarnings = const [];
  int saveCalls = 0;
  @override
  Future<Result<ProjectSaveOutcome>> save(ProjectDocument candidate) async {
    saveCalls++;
    if (failSave) {
      return const Failure(ProjectPersistenceFailure('disk unavailable'));
    }
    document = candidate;
    return Success(
      ProjectSaveOutcome(document: candidate, warnings: nextWarnings),
    );
  }

  @override
  Future<Result<ProjectSaveOutcome>> load(String path) async =>
      Success(ProjectSaveOutcome(document: document, warnings: nextWarnings));
}

final class RecordingProjectDocumentPublisher
    implements ProjectDocumentPublisher {
  ProjectDocument? document;
  List<ProjectSaveWarning> warnings = const [];
  int publishCalls = 0;
  @override
  void publish(
    ProjectDocument next, {
    List<ProjectSaveWarning> warnings = const [],
  }) {
    publishCalls++;
    document = next;
    this.warnings = warnings;
  }
}

final class FakeProjectDocumentLocator implements ProjectDocumentLocator {
  FakeProjectDocumentLocator(this.documentsByPath);
  final Map<String, ProjectDocument> documentsByPath;
  @override
  Future<List<String>> listProjectPaths() async =>
      documentsByPath.keys.toList();

  @override
  Future<ProjectDocument> readDocument(String path) async =>
      documentsByPath[path]!;
}

final class RecordingRenderGateway implements ProjectRenderGateway {
  final List<String> inputPaths = [];
  int renderCalls = 0;
  @override
  void render(List<String> paths) {
    renderCalls++;
    inputPaths.addAll(paths);
  }
}

final class RecordingProjectTransactionGateway
    implements ProjectTransactionGateway {
  final List<EditTransaction> transactions = [];
  int directRepositorySaves = 0;
  @override
  Future<void> apply(EditTransaction transaction) async {
    transactions.add(transaction);
  }
}
