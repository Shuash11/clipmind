import 'package:clipmind/data/models/edit_operation.dart';

class UndoRedoUseCase {
  static const int maxHistorySize = 500;

  final List<EditOperation> _history = [];
  int _position = -1;

  List<EditOperation> get history => List.unmodifiable(_history);

  List<EditOperation> getHistory() => List.unmodifiable(_history);

  bool get canUndo => _position >= 0;

  bool get canRedo => _position < _history.length - 1;

  void push(EditOperation op) {
    if (_position < _history.length - 1) {
      _history.removeRange(_position + 1, _history.length);
    }

    _history.add(op);
    _position = _history.length - 1;

    while (_history.length > maxHistorySize) {
      _history.removeAt(0);
      _position--;
    }
  }

  EditOperation? undo() {
    if (!canUndo) return null;
    final op = _history[_position];
    _position--;
    return op;
  }

  EditOperation? redo() {
    if (!canRedo) return null;
    _position++;
    return _history[_position];
  }

  EditOperation? revertOperation(EditOperation op) {
    switch (op.type) {
      case EditOperationType.trim:
        final start = op.params['start'];
        final end = op.params['end'];
        final originalPath = op.params['originalPath'] as String?;
        if (originalPath == null || start == null || end == null) return null;
        return EditOperation(
          id: '${op.id}_inverse',
          type: EditOperationType.trim,
          targetClipIds: op.targetClipIds,
          params: {
            'start': '0',
            'end': end,
            'restoreOriginal': true,
            'originalPath': originalPath,
            'originalStart': start,
            'originalEnd': end,
          },
          createdAt: DateTime.now(),
          status: OperationStatus.pending,
        );

      case EditOperationType.changeSpeed:
        final factor = (op.params['factor'] as num?)?.toDouble() ?? 1.0;
        if (factor <= 0) return null;
        return EditOperation(
          id: '${op.id}_inverse',
          type: EditOperationType.changeSpeed,
          targetClipIds: op.targetClipIds,
          params: {'factor': 1.0 / factor},
          createdAt: DateTime.now(),
          status: OperationStatus.pending,
        );

      case EditOperationType.mute:
        return EditOperation(
          id: '${op.id}_inverse',
          type: EditOperationType.changeVolume,
          targetClipIds: op.targetClipIds,
          params: {'factor': 1.0},
          createdAt: DateTime.now(),
          status: OperationStatus.pending,
        );

      case EditOperationType.rotate:
        final degrees = (op.params['degrees'] as num?)?.toDouble() ?? 0;
        return EditOperation(
          id: '${op.id}_inverse',
          type: EditOperationType.rotate,
          targetClipIds: op.targetClipIds,
          params: {'degrees': (-degrees) % 360},
          createdAt: DateTime.now(),
          status: OperationStatus.pending,
        );

      case EditOperationType.adjustBrightness:
        return EditOperation(
          id: '${op.id}_inverse',
          type: EditOperationType.adjustBrightness,
          targetClipIds: op.targetClipIds,
          params: {'value': 0.0},
          createdAt: DateTime.now(),
          status: OperationStatus.pending,
        );

      case EditOperationType.changeVolume:
        final factor = (op.params['factor'] as num?)?.toDouble() ?? 1.0;
        if (factor <= 0) return null;
        return EditOperation(
          id: '${op.id}_inverse',
          type: EditOperationType.changeVolume,
          targetClipIds: op.targetClipIds,
          params: {'factor': 1.0 / factor},
          createdAt: DateTime.now(),
          status: OperationStatus.pending,
        );

      case EditOperationType.resize:
        final originalWidth = op.params['originalWidth'];
        final originalHeight = op.params['originalHeight'];
        if (originalWidth == null || originalHeight == null) return null;
        return EditOperation(
          id: '${op.id}_inverse',
          type: EditOperationType.resize,
          targetClipIds: op.targetClipIds,
          params: {
            'width': originalWidth,
            'height': originalHeight,
            'fit': op.params['originalFit'] ?? 'fill',
          },
          createdAt: DateTime.now(),
          status: OperationStatus.pending,
        );

      case EditOperationType.cut:
      case EditOperationType.merge:
      case EditOperationType.overlayText:
      case EditOperationType.extractAudio:
      case EditOperationType.generateThumbnail:
      case EditOperationType.changeFormat:
      case EditOperationType.overlayWatermark:
        return null;
    }
  }

  void clear() {
    _history.clear();
    _position = -1;
  }
}
