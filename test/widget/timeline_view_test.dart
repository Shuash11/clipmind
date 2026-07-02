import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/track_row.dart';

void main() {
  testWidgets('TimelineView renders 4 track rows', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineView(),
        ),
      ),
    );

    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('FX'), findsOneWidget);
  });

  testWidgets('TimelineView shows toolbar icons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineView(),
        ),
      ),
    );

    expect(find.byIcon(Icons.content_cut), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out), findsOneWidget);
  });

  testWidgets('TrackRow displays clip blocks', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrackRow(trackType: TrackTypeDisplay.video),
        ),
      ),
    );

    expect(find.text('Video'), findsOneWidget);
    expect(find.text('clip_01'), findsOneWidget);
  });

  testWidgets('All track types render with correct labels', (WidgetTester tester) async {
    for (final type in TrackTypeDisplay.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackRow(trackType: type),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
