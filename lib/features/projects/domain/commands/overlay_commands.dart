import 'project_command.dart';

final class AddTextOverlayCommand extends ProjectCommand {
  const AddTextOverlayCommand({
    required this.overlayId,
    required this.trackId,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.x,
    required this.y,
  });

  final String overlayId;
  final String trackId;
  final int startMs;
  final int endMs;
  final String text;
  final double x;
  final double y;

  @override
  String get type => 'add_text_overlay';
}

final class AddImageOverlayCommand extends ProjectCommand {
  const AddImageOverlayCommand({
    required this.overlayId,
    required this.trackId,
    required this.assetId,
    required this.startMs,
    required this.endMs,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String overlayId;
  final String trackId;
  final String assetId;
  final int startMs;
  final int endMs;
  final double x;
  final double y;
  final int width;
  final int height;

  @override
  String get type => 'add_image_overlay';
}
