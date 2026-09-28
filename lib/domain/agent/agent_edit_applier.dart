import 'package:clipmind/data/models/edit_operation.dart';

/// Callback invoked to mutate project state after a successful FFmpeg run.
///
/// Implemented in the state layer ([ProjectNotifier.applyEdit] + undo/DB
/// wiring). The domain layer never imports state directly.
///
/// [removeClipIds] lets merging ops (merge_clips, add_transition) replace
/// a clip pair with one output: the first clip is repointed at
/// [newSourcePath] (as today) and the listed clips are removed from the
/// project's tracks. Undo stays a null-inverse — removed clips are not
/// restored (matches the existing merge null-inverse; documented, not
/// silent). Optional so every existing caller compiles unchanged.
typedef ApplyEditCallback = Future<void> Function(
  EditOperation operation,
  String newSourcePath, {
  List<String> removeClipIds,
});

/// Single mutation path for AI edits (and future manual edits).
///
/// The agent loop and any future edit entry points share this applier so
/// all [Project] mutations flow through one place.
class AgentEditApplier {
  final ApplyEditCallback onApply;

  const AgentEditApplier({required this.onApply});

  /// Apply one [EditOperation] whose output lives at [outputPath].
  Future<void> apply(
    EditOperation operation,
    String outputPath, {
    List<String> removeClipIds = const [],
  }) {
    return onApply(operation, outputPath, removeClipIds: removeClipIds);
  }

  /// Apply a batch of operations sharing one output file.
  Future<void> applyAll(
    List<EditOperation> operations,
    String outputPath, {
    List<String> removeClipIds = const [],
  }) async {
    for (final op in operations) {
      await onApply(op, outputPath, removeClipIds: removeClipIds);
    }
  }
}
