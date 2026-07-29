import 'package:clipmind/features/projects/domain/entities/timeline_marker.dart';

final class MarkerLayoutEntry {
  const MarkerLayoutEntry({
    required this.markerId,
    required this.leftPx,
    required this.widthPx,
  });

  final String markerId;
  final double leftPx;
  final double widthPx;
}

final class MarkerLayout {
  static List<MarkerLayoutEntry> layout({
    required Iterable<TimelineMarker> markers,
    required num durationMs,
    required num width,
  }) {
    if (!durationMs.isFinite || !width.isFinite) {
      return const <MarkerLayoutEntry>[];
    }
    final duration = durationMs.toDouble();
    final timelineWidth = width.toDouble();
    if (duration <= 0 || timelineWidth <= 0) {
      return const <MarkerLayoutEntry>[];
    }

    final entries = <MarkerLayoutEntry>[];
    for (final marker in markers) {
      final entry = _entryFor(marker, duration, timelineWidth);
      if (entry != null) entries.add(entry);
    }
    entries.sort((left, right) {
      final byStart = left.leftPx.compareTo(right.leftPx);
      return byStart != 0 ? byStart : left.markerId.compareTo(right.markerId);
    });
    return List.unmodifiable(entries);
  }

  static MarkerLayoutEntry? _entryFor(
    TimelineMarker marker,
    double duration,
    double timelineWidth,
  ) {
    if (_isPoint(marker)) {
      final markerWidth = timelineWidth < 8 ? timelineWidth : 8.0;
      final targetLeft = marker.atMs! / duration * timelineWidth - 4;
      return MarkerLayoutEntry(
        markerId: marker.id,
        leftPx: _clamp(targetLeft, 0, timelineWidth - markerWidth),
        widthPx: markerWidth,
      );
    }
    if (!_isRange(marker)) return null;

    final start = _clamp(
      marker.startMs! / duration * timelineWidth,
      0,
      timelineWidth,
    );
    final end = _clamp(
      marker.endMs! / duration * timelineWidth,
      0,
      timelineWidth,
    );
    if (end <= start || timelineWidth < 4) return null;
    final proportionalWidth = end - start;
    final desiredWidth = proportionalWidth < 4 ? 4.0 : proportionalWidth;
    final markerWidth = desiredWidth > timelineWidth
        ? timelineWidth
        : desiredWidth;
    return MarkerLayoutEntry(
      markerId: marker.id,
      leftPx: _clamp(start, 0, timelineWidth - markerWidth),
      widthPx: markerWidth,
    );
  }

  static bool _isPoint(TimelineMarker marker) =>
      marker.atMs != null &&
      marker.atMs! >= 0 &&
      marker.startMs == null &&
      marker.endMs == null;

  static bool _isRange(TimelineMarker marker) =>
      marker.atMs == null &&
      marker.startMs != null &&
      marker.endMs != null &&
      marker.startMs! >= 0 &&
      marker.endMs! > marker.startMs!;

  static double _clamp(double value, double minimum, double maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
  }
}
