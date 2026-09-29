import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';

/// One undoable step: the PRE-edit project snapshot plus the op that
/// produced the edit (null for op-less structural edits).
typedef UndoEntry = ({Project projectBefore, EditOperation? operation});

/// One redoable step: the POST-edit project snapshot plus the op.
typedef RedoEntry = ({Project projectAfter, EditOperation? operation});

/// Memento snapshot undo for timeline edits.
///
/// Uniform for ALL op types — including pair-replacement (`removeClipIds`),
/// captions and effects — because undo restores the whole pre-edit
/// [Project] instead of inverting individual ops. [Project] is immutable
/// freezed, so snapshots are safe copies.
///
/// Memento order at every mutation site: snapshot first, then mutate.
///
/// Policy for external resources (documented, not silent): undo restores
/// the in-memory project (the caller persists the project file); old
/// output files remain on disk (harmless); DB op rows remain untouched as
/// the historical journal (the op WAS applied then reverted; the project
/// state is authoritative).
class UndoRedoUseCase {
  static const int maxHistorySize = 500;

  final List<UndoEntry> _undoStack = [];
  final List<RedoEntry> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Depth of the undo stack (for status/UI enablement).
  int get undoDepth => _undoStack.length;

  /// FFmpeg edits: snapshot the PRE-edit project + the op.
  /// Clears the redo stack (standard undo semantics).
  void pushEdit(Project projectBefore, EditOperation operation) {
    _undoStack.add((projectBefore: projectBefore, operation: operation));
    _redoStack.clear();
    _trim();
  }

  /// Manual structural edits (delete/copy): snapshot only, no op.
  /// Clears the redo stack (standard undo semantics).
  void pushStructural(Project projectBefore) {
    _undoStack.add((projectBefore: projectBefore, operation: null));
    _redoStack.clear();
    _trim();
  }

  /// Undo: returns the PRE-edit project to restore + the op (for UI
  /// confirmation). [projectNow] becomes the redo target.
  /// Returns null when there is nothing to undo.
  ({Project project, EditOperation? operation})? undo(Project projectNow) {
    if (_undoStack.isEmpty) return null;
    final entry = _undoStack.removeLast();
    _redoStack.add((projectAfter: projectNow, operation: entry.operation));
    return (project: entry.projectBefore, operation: entry.operation);
  }

  /// Redo: returns the POST-edit project to restore + the op.
  /// [projectNow] becomes the undo target.
  /// Returns null when there is nothing to redo.
  ({Project project, EditOperation? operation})? redo(Project projectNow) {
    if (_redoStack.isEmpty) return null;
    final entry = _redoStack.removeLast();
    _undoStack.add((projectBefore: projectNow, operation: entry.operation));
    return (project: entry.projectAfter, operation: entry.operation);
  }

  void _trim() {
    while (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
