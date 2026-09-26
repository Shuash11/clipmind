import 'package:clipmind/features/projects/domain/entities/timeline_marker.dart';
import 'package:clipmind/features/tagging/domain/marker_filter.dart';
import 'package:clipmind/features/tagging/domain/marker_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'marker filter owns selections and filters colors and point/range shapes',
    () {
      final colors = <String>{'#FF0000'};
      final markers = [
        _point('point-red', 100, '#FF0000'),
        _range('range-red', 100, 200, '#FF0000'),
        _point('point-blue', 300, '#0000FF'),
        const TimelineMarker(
          id: 'invalid-both',
          label: 'Invalid',
          color: '#FF0000',
          atMs: 100,
          startMs: 100,
          endMs: 200,
        ),
      ];
      final filter = MarkerFilter(
        selectedColors: colors,
        includePoints: true,
        includeRanges: false,
      );
      colors.clear();

      expect(filter.selectedColors, {'#FF0000'});
      expect(
        () => filter.selectedColors.add('#0000FF'),
        throwsUnsupportedError,
      );
      expect(filter.filter(markers).map((marker) => marker.id), ['point-red']);
      expect(
        MarkerFilter(
          includePoints: false,
          includeRanges: true,
        ).filter(markers).map((marker) => marker.id),
        ['range-red'],
      );
      expect(MarkerFilter().filter(markers).map((marker) => marker.id), [
        'point-red',
        'range-red',
        'point-blue',
      ]);
    },
  );

  test(
    'lays out points at exactly 8px and ranges proportionally with 4px minimum',
    () {
      final entries = MarkerLayout.layout(
        markers: [
          _point('point', 500, '#111111'),
          _range('short-range', 250, 260, '#222222'),
          _range('long-range', 500, 900, '#333333'),
        ],
        durationMs: 1000,
        width: 100,
      );

      expect(entries.map((entry) => entry.markerId), [
        'short-range',
        'point',
        'long-range',
      ]);
      final shortRange = entries.firstWhere(
        (entry) => entry.markerId == 'short-range',
      );
      final point = entries.firstWhere((entry) => entry.markerId == 'point');
      final longRange = entries.firstWhere(
        (entry) => entry.markerId == 'long-range',
      );
      expect(shortRange.leftPx, 25);
      expect(shortRange.widthPx, 4);
      expect(point.leftPx, 46);
      expect(point.widthPx, 8);
      expect(longRange.leftPx, 50);
      expect(longRange.widthPx, 40);
    },
  );

  test(
    'clamps edges, deterministically breaks overlapping ties, and owns output',
    () {
      final source = [
        _point('z-last', 500, '#111111'),
        _point('a-first', 500, '#222222'),
        _point('at-start', 0, '#333333'),
        _point('at-end', 1000, '#444444'),
        _range('range-at-end', 950, 1100, '#555555'),
        _range('short-range-at-end', 990, 1000, '#666666'),
      ];
      final sourceIds = source.map((marker) => marker.id).toList();

      final entries = MarkerLayout.layout(
        markers: source,
        durationMs: 1000,
        width: 100,
      );

      expect(entries.map((entry) => entry.markerId), [
        'at-start',
        'a-first',
        'z-last',
        'at-end',
        'range-at-end',
        'short-range-at-end',
      ]);
      expect(entries.first.leftPx, 0);
      expect(
        entries.firstWhere((entry) => entry.markerId == 'at-end').leftPx,
        92,
      );
      final rangeAtEnd = entries.firstWhere(
        (entry) => entry.markerId == 'range-at-end',
      );
      expect(rangeAtEnd.leftPx, 95);
      expect(rangeAtEnd.widthPx, 5);
      final shortRangeAtEnd = entries.firstWhere(
        (entry) => entry.markerId == 'short-range-at-end',
      );
      expect(shortRangeAtEnd.leftPx, 96);
      expect(shortRangeAtEnd.widthPx, 4);
      expect(() => entries.add(entries.first), throwsUnsupportedError);
      expect(source.map((marker) => marker.id), sourceIds);
    },
  );

  test(
    'omits invalid marker shapes and rejects non-positive layout dimensions',
    () {
      final markers = [
        _point('valid', 100, '#111111'),
        const TimelineMarker(
          id: 'both',
          label: 'Both',
          color: '#222222',
          atMs: 100,
          startMs: 100,
          endMs: 200,
        ),
        _range('empty-range', 200, 200, '#333333'),
        const TimelineMarker(
          id: 'incomplete-range',
          label: 'Incomplete',
          color: '#444444',
          startMs: 200,
        ),
      ];

      expect(
        MarkerLayout.layout(
          markers: markers,
          durationMs: 1000,
          width: 100,
        ).map((entry) => entry.markerId),
        ['valid'],
      );
      expect(
        MarkerLayout.layout(markers: markers, durationMs: 0, width: 100),
        isEmpty,
      );
      expect(
        MarkerLayout.layout(markers: markers, durationMs: 1000, width: 0),
        isEmpty,
      );
    },
  );
}

TimelineMarker _point(String id, int atMs, String color) =>
    TimelineMarker(id: id, label: id, color: color, atMs: atMs);

TimelineMarker _range(String id, int startMs, int endMs, String color) =>
    TimelineMarker(
      id: id,
      label: id,
      color: color,
      startMs: startMs,
      endMs: endMs,
    );
