import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/domain/usecases/undo_redo_usecase.dart';
import 'package:clipmind/state/project_providers.dart';

class UndoRedoState {
  final bool canUndo;
  final bool canRedo;
  final int historyCount;
  final int position;

  const UndoRedoState({
    required this.canUndo,
    required this.canRedo,
    required this.historyCount,
    required this.position,
  });
}

class UndoRedoNotifier extends StateNotifier<UndoRedoState> {
  final UndoRedoUseCase _useCase;
  final Ref _ref;
  final Future<void> Function(Project project) _onRestore;

  UndoRedoNotifier(this._useCase, this._ref, {required this._onRestore})
      : super(
          const UndoRedoState(
            canUndo: false,
            canRedo: false,
            historyCount: 0,
            position: -1,
          ),
        );

  UndoRedoUseCase get useCase => _useCase;

  /// FFmpeg edits: the caller passes the PRE-edit snapshot (memento order:
  /// snapshot first, then mutate). Clears redo.
  void pushEdit(Project projectBefore, EditOperation operation) {
    _useCase.pushEdit(projectBefore, operation);
    _emitState();
  }

  /// Manual structural edits (delete/copy): snapshot only, no op.
  void pushStructural(Project projectBefore) {
    _useCase.pushStructural(projectBefore);
    _emitState();
  }

  /// Undo: restores the pre-edit project (in-memory + file via [onRestore])
  /// and returns the op for UI confirmation. Null when nothing to undo.
  Future<EditOperation?> undo() async {
    final projectNow = _ref.read(projectProvider).valueOrNull;
    if (projectNow == null) {
      _emitState();
      return null;
    }
    final result = _useCase.undo(projectNow);
    if (result == null) {
      _emitState();
      return null;
    }
    await _onRestore(result.project);
    _emitState();
    return result.operation;
  }

  /// Redo: restores the post-edit project. Null when nothing to redo.
  Future<EditOperation?> redo() async {
    final projectNow = _ref.read(projectProvider).valueOrNull;
    if (projectNow == null) {
      _emitState();
      return null;
    }
    final result = _useCase.redo(projectNow);
    if (result == null) {
      _emitState();
      return null;
    }
    await _onRestore(result.project);
    _emitState();
    return result.operation;
  }

  void clear() {
    _useCase.clear();
    _emitState();
  }

  void _emitState() {
    state = UndoRedoState(
      canUndo: _useCase.canUndo,
      canRedo: _useCase.canRedo,
      historyCount: _useCase.undoDepth,
      position: _useCase.undoDepth > 0 ? _useCase.undoDepth - 1 : -1,
    );
  }
}

final undoRedoProvider = StateNotifierProvider<UndoRedoNotifier, UndoRedoState>((
  ref,
) {
  return UndoRedoNotifier(
    UndoRedoUseCase(),
    ref,
    onRestore: (project) async {
      ref.read(projectProvider.notifier).setProject(project);
      try {
        await ref.read(projectRepositoryProvider).save(project);
      } catch (_) {}
    },
  );
});
