import 'package:clipmind/features/projects/domain/commands/marker_commands.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';

final class TaggingController {
  const TaggingController(this._commandFactory);

  final ProjectCommandFactory _commandFactory;

  CreateTagCommand createTag({required String name, required String color}) =>
      _commandFactory.createTag(name: name, color: color);

  UpdateTagCommand updateTag({
    required String tagId,
    required String name,
    required String color,
  }) => _commandFactory.updateTag(tagId: tagId, name: name, color: color);

  DeleteTagCommand deleteTag({required String tagId}) =>
      _commandFactory.deleteTag(tagId: tagId);

  AssignTagCommand assignTag({
    required String tagId,
    required AssignmentTargetKind targetKind,
    required String targetId,
  }) => _commandFactory.assignTag(
    tagId: tagId,
    targetKind: targetKind,
    targetId: targetId,
  );

  UnassignTagCommand unassignTag({
    required String tagId,
    required AssignmentTargetKind targetKind,
    required String targetId,
  }) => _commandFactory.unassignTag(
    tagId: tagId,
    targetKind: targetKind,
    targetId: targetId,
  );

  CreateMarkerCommand createMarker({
    required String label,
    required String color,
    int? atMs,
    int? startMs,
    int? endMs,
  }) => _commandFactory.createMarker(
    label: label,
    color: color,
    atMs: atMs,
    startMs: startMs,
    endMs: endMs,
  );

  UpdateMarkerCommand updateMarker({
    required String markerId,
    required String label,
    required String color,
    int? atMs,
    int? startMs,
    int? endMs,
  }) => _commandFactory.updateMarker(
    markerId: markerId,
    label: label,
    color: color,
    atMs: atMs,
    startMs: startMs,
    endMs: endMs,
  );

  DeleteMarkerCommand deleteMarker({required String markerId}) =>
      _commandFactory.deleteMarker(markerId: markerId);
}
