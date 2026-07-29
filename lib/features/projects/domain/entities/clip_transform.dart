enum ClipFit { contain, cover, stretch }

final class ClipTransform {
  const ClipTransform({
    required this.width,
    required this.height,
    required this.fit,
    required this.rotationDegrees,
  });

  final int width;
  final int height;
  final ClipFit fit;
  final int rotationDegrees;

  Map<String, Object?> toJson() => {
    'width': width,
    'height': height,
    'fit': fit.name,
    'rotationDegrees': rotationDegrees,
  };

  factory ClipTransform.fromJson(Map<String, Object?> json) => ClipTransform(
    width: json['width'] as int,
    height: json['height'] as int,
    fit: ClipFit.values.byName(json['fit'] as String),
    rotationDegrees: json['rotationDegrees'] as int,
  );

  @override
  bool operator ==(Object other) =>
      other is ClipTransform &&
      width == other.width &&
      height == other.height &&
      fit == other.fit &&
      rotationDegrees == other.rotationDegrees;

  @override
  int get hashCode => Object.hash(width, height, fit, rotationDegrees);
}
