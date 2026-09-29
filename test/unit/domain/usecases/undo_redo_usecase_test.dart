import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/domain/usecases/undo_redo_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

Project _project(String name) {
  return Project(
    id: 'p1',
    name: name,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const [],
    tracks: const [],
    durationMs: 0,
    outputDir: '/out',
  );
}

EditOperation _op(String id) {
  return EditOperation(
    id: id,
    type: EditOperationType.trim,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('UndoRedoUseCase snapshots', () {
    test('empty stacks undo/redo nothing', () {
      final useCase = UndoRedoUseCase();
      final now = _project('now');

      expect(useCase.canUndo, isFalse);
      expect(useCase.canRedo, isFalse);
      expect(useCase.undoDepth, equals(0));
      expect(useCase.undo(now), isNull);
      expect(useCase.redo(now), isNull);
    });

    test('pushEdit then undo returns the pre-edit project and op',
        () async {
      final useCase = UndoRedoUseCase();
      final before = _project('before');
      final after = _project('after');
      final op = _op('op_1');
      useCase.pushEdit(before, op);

      expect(useCase.canUndo, isTrue);
      expect(useCase.canRedo, isFalse);
      expect(useCase.undoDepth, equals(1));

      final undone = useCase.undo(after);
      expect(identical(undone!.project, before), isTrue);
      expect(identical(undone.operation, op), isTrue);

      expect(useCase.canUndo, isFalse);
      expect(useCase.canRedo, isTrue);
    });

    test('redo returns the post-edit project and op', () async {
      final useCase = UndoRedoUseCase();
      final before = _project('before');
      final after = _project('after');
      final op = _op('op_1');
      useCase.pushEdit(before, op);
      useCase.undo(after);

      final redone = useCase.redo(before);
      expect(identical(redone!.project, after), isTrue);
      expect(identical(redone.operation, op), isTrue);

      expect(useCase.canUndo, isTrue);
      expect(useCase.canRedo, isFalse);
    });

    test('pushStructural snapshots without an op', () async {
      final useCase = UndoRedoUseCase();
      final before = _project('before');
      final after = _project('after');
      useCase.pushStructural(before);

      expect(useCase.canUndo, isTrue);
      final undone = useCase.undo(after);
      expect(identical(undone!.project, before), isTrue);
      expect(undone.operation, isNull);

      final redone = useCase.redo(before);
      expect(identical(redone!.project, after), isTrue);
      expect(redone.operation, isNull);
    });

    test('multi-level undo/redo keeps op association', () async {
      final useCase = UndoRedoUseCase();
      final p0 = _project('p0');
      final p1 = _project('p1');
      final p2 = _project('p2');
      final op1 = _op('op_1');
      final op2 = _op('op_2');
      useCase.pushEdit(p0, op1);
      useCase.pushEdit(p1, op2);

      final undo2 = useCase.undo(p2);
      expect(identical(undo2!.project, p1), isTrue);
      expect(identical(undo2.operation, op2), isTrue);
      final undo1 = useCase.undo(p1);
      expect(identical(undo1!.project, p0), isTrue);
      expect(identical(undo1.operation, op1), isTrue);
      expect(useCase.canUndo, isFalse);

      final redo1 = useCase.redo(p0);
      expect(identical(redo1!.project, p1), isTrue);
      expect(identical(redo1.operation, op1), isTrue);
      final redo2 = useCase.redo(p1);
      expect(identical(redo2!.project, p2), isTrue);
      expect(identical(redo2.operation, op2), isTrue);
      expect(useCase.canRedo, isFalse);
    });

    test('a new edit clears the redo stack', () async {
      final useCase = UndoRedoUseCase();
      final p0 = _project('p0');
      final p1 = _project('p1');
      final p2 = _project('p2');
      useCase.pushEdit(p0, _op('op_1'));
      useCase.undo(p1);
      expect(useCase.canRedo, isTrue);

      useCase.pushEdit(p0, _op('op_2'));
      expect(useCase.canRedo, isFalse);
      expect(useCase.redo(p2), isNull);
      // The undone entry was consumed by undo(); only the new push remains.
      expect(useCase.undoDepth, equals(1));
    });

    test('a structural edit also clears the redo stack', () async {
      final useCase = UndoRedoUseCase();
      final p0 = _project('p0');
      final p1 = _project('p1');
      useCase.pushEdit(p0, _op('op_1'));
      useCase.undo(p1);

      useCase.pushStructural(p0);
      expect(useCase.canRedo, isFalse);
    });

    test('history trims the oldest beyond maxHistorySize', () async {
      final useCase = UndoRedoUseCase();
      final names = List.generate(
        UndoRedoUseCase.maxHistorySize + 2,
        (i) => 'p$i',
      );
      for (final name in names) {
        useCase.pushStructural(_project(name));
      }

      expect(useCase.undoDepth, equals(UndoRedoUseCase.maxHistorySize));

      final restored = <String>[];
      var current = _project('tip');
      while (useCase.canUndo) {
        final undone = useCase.undo(current)!;
        restored.add(undone.project.name);
        current = undone.project;
      }
      expect(restored, hasLength(UndoRedoUseCase.maxHistorySize));
      // The two oldest snapshots were trimmed.
      expect(restored.last, equals('p2'));
      expect(restored, isNot(contains('p0')));
      expect(restored, isNot(contains('p1')));
    });

    test('clear empties both stacks', () async {
      final useCase = UndoRedoUseCase();
      final p0 = _project('p0');
      final p1 = _project('p1');
      useCase.pushEdit(p0, _op('op_1'));
      useCase.undo(p1);

      useCase.clear();

      expect(useCase.canUndo, isFalse);
      expect(useCase.canRedo, isFalse);
      expect(useCase.undoDepth, equals(0));
    });
  });
}
