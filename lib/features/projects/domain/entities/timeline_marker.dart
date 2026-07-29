final class TimelineMarker {
  const TimelineMarker({
    required this.id,
    required this.label,
    required this.color,
    this.atMs,
    this.startMs,
    this.endMs,
  });

  final String id;
  final String label;
  final String color;
  final int? atMs;
  final int? startMs;
  final int? endMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'color': color,
    'atMs': atMs,
    'startMs': startMs,
    'endMs': endMs,
  };

  factory TimelineMarker.fromJson(Map<String, Object?> json) => TimelineMarker(
    id: json['id'] as String,
    label: json['label'] as String,
    color: json['color'] as String,
    atMs: json['atMs'] as int?,
    startMs: json['startMs'] as int?,
    endMs: json['endMs'] as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is TimelineMarker &&
      id == other.id &&
      label == other.label &&
      color == other.color &&
      atMs == other.atMs &&
      startMs == other.startMs &&
      endMs == other.endMs;

  @override
  int get hashCode => Object.hash(id, label, color, atMs, startMs, endMs);
}
