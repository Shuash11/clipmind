import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/domain/usecases/structural_edit_usecase.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';

/// Single mutation path for structural ops (`deleteClip`/`copyClip`/
/// `moveClip`): pre-edit snapshot → local transform → undo/DB/file.
///
/// Mirrors [agentEditApplierProvider] without FFmpeg: Package C reads
/// `ref.read(structuralEditApplierProvider).apply(operation)`.
///
/// Returns true when the op applied; false is a graceful no-op (unknown
/// clip/type, or no project open) that pushes nothing to the undo stack.
final structuralEditApplierProvider = Provider<StructuralEditApplier>((ref) {
  return StructuralEditApplier(ref);
});

class StructuralEditApplier {
  final Ref _ref;

  const StructuralEditApplier(this._ref);

  Future<bool> apply(EditOperation operation) async {
    final project = _ref.read(projectProvider).valueOrNull;
    if (project == null) return false;

    // The transform is pure: validate first so a no-op never pushes a
    // bogus undo entry (memento order still holds — `project` is the
    // immutable pre-edit snapshot).
    final preview =
        const StructuralEditUseCase().apply(operation, project);
    if (preview == null) return false;

    _ref.read(undoRedoProvider.notifier).pushEdit(project, operation);
    _ref.read(projectProvider.notifier).applyStructuralEdit(operation);

    try {
      await _ref
          .read(appDatabaseProvider)
          .saveEditOperation(project.id, operation);
    } catch (_) {
      // DB journal is best-effort; in-memory + undo already updated.
    }
    try {
      final updated = _ref.read(projectProvider).valueOrNull;
      if (updated != null) {
        await _ref.read(projectRepositoryProvider).save(updated);
      }
    } catch (_) {
      // File persistence is best-effort; in-memory + DB already updated.
    }
    return true;
  }
}
