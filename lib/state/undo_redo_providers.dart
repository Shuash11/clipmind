import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/domain/usecases/undo_redo_usecase.dart';

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

  UndoRedoNotifier(this._useCase)
      : super(UndoRedoState(
          canUndo: false,
          canRedo: false,
          historyCount: 0,
          position: -1,
        ));

  UndoRedoUseCase get useCase => _useCase;

  void push(EditOperation op) {
    _useCase.push(op);
    _emitState();
  }

  EditOperation? undo() {
    final op = _useCase.undo();
    _emitState();
    return op;
  }

  EditOperation? redo() {
    final op = _useCase.redo();
    _emitState();
    return op;
  }

  EditOperation? revertOperation(EditOperation op) {
    return _useCase.revertOperation(op);
  }

  void clear() {
    _useCase.clear();
    _emitState();
  }

  void _emitState() {
    state = UndoRedoState(
      canUndo: _useCase.canUndo,
      canRedo: _useCase.canRedo,
      historyCount: _useCase.history.length,
      position: _useCase.history.isNotEmpty
          ? (_useCase.history.length - 1)
          : -1,
    );
  }
}

final undoRedoProvider =
    StateNotifierProvider<UndoRedoNotifier, UndoRedoState>((ref) {
  final useCase = UndoRedoUseCase();
  return UndoRedoNotifier(useCase);
});
