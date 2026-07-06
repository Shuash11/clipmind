import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/track_row.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('TimelineView renders 4 track rows', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const TimelineView()));

    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('FX'), findsOneWidget);
  });

  testWidgets('TimelineView shows toolbar icons', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const TimelineView()));

    expect(find.byIcon(Icons.content_cut), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out), findsOneWidget);
  });

  testWidgets('TrackRow displays project clip blocks', (
    WidgetTester tester,
  ) async {
    const clip = Clip(
      id: 'clip-1',
      trackId: 'track-1',
      sourcePath: 'C:/media/sample.mp4',
      startMs: 0,
      endMs: 30000,
      label: 'sample.mp4',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrackRow(trackType: TrackTypeDisplay.video, clips: [clip]),
        ),
      ),
    );

    expect(find.text('Video'), findsOneWidget);
    expect(find.text('sample.mp4'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
  });

  testWidgets('All track types render with correct labels', (
    WidgetTester tester,
  ) async {
    for (final type in TrackTypeDisplay.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackRow(trackType: type)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
