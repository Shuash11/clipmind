import 'project_command.dart';

enum AssignmentTargetKind { asset, clip }

final class CreateTagCommand extends ProjectCommand {
  const CreateTagCommand({
    required this.tagId,
    required this.name,
    required this.color,
  });

  final String tagId;
  final String name;
  final String color;

  @override
  String get type => 'create_tag';
}

final class UpdateTagCommand extends ProjectCommand {
  const UpdateTagCommand({
    required this.tagId,
    required this.name,
    required this.color,
  });

  final String tagId;
  final String name;
  final String color;

  @override
  String get type => 'update_tag';
}

final class DeleteTagCommand extends ProjectCommand {
  const DeleteTagCommand({required this.tagId});

  final String tagId;

  @override
  String get type => 'delete_tag';
}

final class AssignTagCommand extends ProjectCommand {
  const AssignTagCommand({
    required this.tagId,
    required this.targetKind,
    required this.targetId,
  });

  final String tagId;
  final AssignmentTargetKind targetKind;
  final String targetId;

  @override
  String get type => 'assign_tag';
}

final class UnassignTagCommand extends ProjectCommand {
  const UnassignTagCommand({
    required this.tagId,
    required this.targetKind,
    required this.targetId,
  });

  final String tagId;
  final AssignmentTargetKind targetKind;
  final String targetId;

  @override
  String get type => 'unassign_tag';
}
