import 'package:clipmind/data/models/edit_operation.dart';

/// Callback invoked to mutate project state after a successful FFmpeg run.
///
/// Implemented in the state layer ([ProjectNotifier.applyEdit] + undo/DB
/// wiring). The domain layer never imports state directly.
typedef ApplyEditCallback = Future<void> Function(
  EditOperation operation,
  String newSourcePath,
);

/// Single mutation path for AI edits (and future manual edits).
///
/// The agent loop and any future edit entry points share this applier so
/// all [Project] mutations flow through one place.
class AgentEditApplier {
  final ApplyEditCallback onApply;

  const AgentEditApplier({required this.onApply});

  /// Apply one [EditOperation] whose output lives at [outputPath].
  Future<void> apply(EditOperation operation, String outputPath) {
    return onApply(operation, outputPath);
  }

  /// Apply a batch of operations sharing one output file.
  Future<void> applyAll(
    List<EditOperation> operations,
    String outputPath,
  ) async {
    for (final op in operations) {
      await onApply(op, outputPath);
    }
  }
}
