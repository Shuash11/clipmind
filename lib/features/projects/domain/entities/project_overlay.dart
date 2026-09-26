enum ProjectOverlayKind { text, image }

final class ProjectOverlay {
  const ProjectOverlay._({
    required this.id,
    required this.kind,
    required this.trackId,
    required this.startMs,
    required this.endMs,
    required this.x,
    required this.y,
    this.text,
    this.assetId,
    this.width,
    this.height,
  });

  const ProjectOverlay.text({
    required String id,
    required String trackId,
    required int startMs,
    required int endMs,
    required String text,
    required double x,
    required double y,
  }) : this._(
         id: id,
         kind: ProjectOverlayKind.text,
         trackId: trackId,
         startMs: startMs,
         endMs: endMs,
         text: text,
         x: x,
         y: y,
       );

  const ProjectOverlay.image({
    required String id,
    required String trackId,
    required int startMs,
    required int endMs,
    required String assetId,
    required double x,
    required double y,
    required int width,
    required int height,
  }) : this._(
         id: id,
         kind: ProjectOverlayKind.image,
         trackId: trackId,
         startMs: startMs,
         endMs: endMs,
         assetId: assetId,
         x: x,
         y: y,
         width: width,
         height: height,
       );

  final String id;
  final ProjectOverlayKind kind;
  final String trackId;
  final int startMs;
  final int endMs;
  final String? text;
  final String? assetId;
  final double x;
  final double y;
  final int? width;
  final int? height;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'trackId': trackId,
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
    'assetId': assetId,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory ProjectOverlay.fromJson(Map<String, Object?> json) =>
      ProjectOverlay._(
        id: json['id'] as String,
        kind: ProjectOverlayKind.values.byName(json['kind'] as String),
        trackId: json['trackId'] as String,
        startMs: json['startMs'] as int,
        endMs: json['endMs'] as int,
        text: json['text'] as String?,
        assetId: json['assetId'] as String?,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: json['width'] as int?,
        height: json['height'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is ProjectOverlay &&
      id == other.id &&
      kind == other.kind &&
      trackId == other.trackId &&
      startMs == other.startMs &&
      endMs == other.endMs &&
      text == other.text &&
      assetId == other.assetId &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    trackId,
    startMs,
    endMs,
    text,
    assetId,
    x,
    y,
    width,
    height,
  );
}
