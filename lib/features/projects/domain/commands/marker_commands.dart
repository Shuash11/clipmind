import 'project_command.dart';

final class CreateMarkerCommand extends ProjectCommand {
  const CreateMarkerCommand({
    required this.markerId,
    required this.label,
    required this.color,
    this.atMs,
    this.startMs,
    this.endMs,
  });

  final String markerId;
  final String label;
  final String color;
  final int? atMs;
  final int? startMs;
  final int? endMs;

  @override
  String get type => 'create_marker';
}

final class UpdateMarkerCommand extends ProjectCommand {
  const UpdateMarkerCommand({
    required this.markerId,
    required this.label,
    required this.color,
    this.atMs,
    this.startMs,
    this.endMs,
  });

  final String markerId;
  final String label;
  final String color;
  final int? atMs;
  final int? startMs;
  final int? endMs;

  @override
  String get type => 'update_marker';
}

final class DeleteMarkerCommand extends ProjectCommand {
  const DeleteMarkerCommand({required this.markerId});

  final String markerId;

  @override
  String get type => 'delete_marker';
}
