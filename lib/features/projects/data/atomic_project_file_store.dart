import 'package:clipmind/core/results/result.dart';
import '../domain/transactions/project_file_write_outcome.dart';
import 'project_document_codec.dart';
import 'project_file_io.dart';

final class ProjectReadResult {
  ProjectReadResult({
    required this.json,
    required this.recoveredFromRollback,
    List<ProjectFileWarning> warnings = const [],
  }) : warnings = List.unmodifiable(warnings);

  final String json;
  final bool recoveredFromRollback;
  final List<ProjectFileWarning> warnings;
}

final class AtomicProjectFileStore {
  const AtomicProjectFileStore(this._io, {required this.validator});
  final ProjectFileIo _io;
  final ProjectDocumentValidator validator;

  Future<Result<ProjectFileWriteOutcome>> writeJson(
    String path,
    String json, {
    int? migrationFromSchema,
  }) async {
    if (validator.validateJson(json) case Failure<void>()) {
      return const Failure(
        ProjectPersistenceFailure('Invalid candidate project JSON'),
      );
    }
    final tmp = '$path.tmp';
    final rollback = '$path.rollback';
    try {
      await _io.writeAndFlush(tmp, json);
    } catch (_) {
      return const Failure(
        ProjectPersistenceFailure('Unable to flush temporary project file'),
      );
    }
    final hadTarget = await _io.exists(path);
    if (!hadTarget) {
      try {
        await _io.rename(tmp, path);
        return const Success(ProjectFileWriteOutcome());
      } catch (_) {
        return const Failure(
          ProjectPersistenceFailure('Unable to promote new project file'),
        );
      }
    }
    if (migrationFromSchema != null) {
      try {
        await _io.copy(path, '$path.v$migrationFromSchema.bak');
      } catch (_) {
        return const Failure(
          ProjectPersistenceFailure('Unable to create migration backup'),
        );
      }
    }
    try {
      await _io.rename(path, rollback);
    } catch (_) {
      return const Failure(
        ProjectPersistenceFailure('Unable to prepare rollback file'),
      );
    }
    try {
      await _io.rename(tmp, path);
    } catch (_) {
      try {
        await _io.rename(rollback, path);
        return const Failure(
          ProjectPersistenceFailure(
            'Unable to promote project file; previous file restored',
          ),
        );
      } catch (_) {
        return const Failure(
          ProjectRecoveryFailure(
            'Unable to promote project file or restore rollback',
          ),
        );
      }
    }
    try {
      await _io.delete(rollback);
      return const Success(ProjectFileWriteOutcome());
    } catch (_) {
      return const Success(
        ProjectFileWriteOutcome(
          warning: ProjectFileWarning(
            'rollback_cleanup_failed',
            'Rollback cleanup failed after durable promotion',
          ),
        ),
      );
    }
  }

  Future<Result<ProjectReadResult>> recover(
    String path, {
    ProjectDocumentValidator? validatorOverride,
  }) async {
    final activeValidator = validatorOverride ?? validator;
    final rollback = '$path.rollback';
    final targetExists = await _io.exists(path);
    final rollbackExists = await _io.exists(rollback);
    if (!targetExists && !rollbackExists) {
      return const Failure(ProjectRecoveryFailure('Project file is missing'));
    }
    if (!targetExists) {
      try {
        final json = await _io.read(rollback);
        if (activeValidator.validateJson(json) case Failure<void>()) {
          return const Failure(
            ProjectRecoveryFailure('Recovered rollback is invalid'),
          );
        }
        await _io.rename(rollback, path);
        return Success(
          ProjectReadResult(json: json, recoveredFromRollback: true),
        );
      } catch (_) {
        return const Failure(
          ProjectRecoveryFailure('Unable to restore rollback'),
        );
      }
    }
    try {
      final json = await _io.read(path);
      if (activeValidator.validateJson(json) case Failure<void>()) {
        return const Failure(
          ProjectRecoveryFailure(
            'Project target is corrupt; rollback retained',
          ),
        );
      }
      if (!rollbackExists) {
        return Success(
          ProjectReadResult(json: json, recoveredFromRollback: false),
        );
      }
      try {
        await _io.delete(rollback);
        return Success(
          ProjectReadResult(json: json, recoveredFromRollback: false),
        );
      } catch (_) {
        return Success(
          ProjectReadResult(
            json: json,
            recoveredFromRollback: false,
            warnings: const [
              ProjectFileWarning(
                'rollback_cleanup_failed',
                'Stale rollback cleanup failed',
              ),
            ],
          ),
        );
      }
    } catch (_) {
      return const Failure(
        ProjectRecoveryFailure('Unable to read project target'),
      );
    }
  }
}
