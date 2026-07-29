import 'package:clipmind/features/projects/domain/entities/timeline_marker.dart';

final class MarkerFilter {
  MarkerFilter({
    Set<String> selectedColors = const {},
    this.includePoints = true,
    this.includeRanges = true,
  }) : selectedColors = Set.unmodifiable(selectedColors);

  final Set<String> selectedColors;
  final bool includePoints;
  final bool includeRanges;

  List<TimelineMarker> filter(Iterable<TimelineMarker> markers) {
    final matches = <TimelineMarker>[];
    for (final marker in markers) {
      final isPoint = _isPoint(marker);
      final isRange = _isRange(marker);
      final matchesType =
          (includePoints && isPoint) || (includeRanges && isRange);
      final matchesColor =
          selectedColors.isEmpty || selectedColors.contains(marker.color);
      if (matchesType && matchesColor) matches.add(marker);
    }
    return List.unmodifiable(matches);
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
}
