import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';
import 'package:clipmind/features/projects/domain/entities/timeline_marker.dart';
import 'package:clipmind/features/tagging/presentation/widgets/marker_editor_dialog.dart';
import 'package:clipmind/features/tagging/presentation/widgets/marker_filter_menu.dart';
import 'package:clipmind/features/tagging/presentation/widgets/marker_ruler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tagging_widget_harness.dart';

void main() {
  testWidgets(
    'renders filtered canonical point and range marker geometry/colors',
    (tester) async {
      final harness = _markerHarness();
      await tester.pumpWidget(
        taggingTestApp(
          harness: harness,
          child: const Column(
            children: [
              MarkerFilterMenu(),
              MarkerRuler(durationMs: 1000, width: 100),
            ],
          ),
        ),
      );

      final point = find.byKey(const ValueKey('marker-ruler-marker-point-1'));
      final range = find.byKey(const ValueKey('marker-ruler-marker-range-1'));
      expect(point, findsOneWidget);
      expect(range, findsOneWidget);
      expect(
        find.bySemanticsLabel('Marker Beat at 200 ms, color #1299AA'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Marker Intro from 300 ms to 700 ms, color #AA5511',
        ),
        findsOneWidget,
      );
      expect(tester.getSize(point).width, closeTo(8, 0.01));
      expect(tester.getSize(range).width, closeTo(40, 0.01));

      await tester.tap(find.bySemanticsLabel('Show point markers'));
      await tester.pump();
      expect(point, findsNothing);
      expect(range, findsOneWidget);
    },
  );

  testWidgets(
    'opens editor on Enter and deletes through one manual transaction',
    (tester) async {
      final harness = _markerHarness();
      await tester.pumpWidget(
        taggingTestApp(
          harness: harness,
          child: const MarkerRuler(durationMs: 1000, width: 100),
        ),
      );
      final point = find.byKey(const ValueKey('marker-ruler-marker-point-1'));
      await tester.tap(point);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(MarkerEditorDialog), findsOneWidget);
      expect(harness.repository.saveCalls, 0);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(point);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(harness.repository.saveCalls, 1);
      expect(
        harness.document.history.single.sourceKind,
        TransactionSourceKind.manual,
      );
      expect(
        harness.document.history.single.commands.single.type,
        'delete_marker',
      );
    },
  );

  testWidgets('moves and resizes markers by exact safe 100ms increments', (
    tester,
  ) async {
    final pointHarness = _markerHarness(pointAt: 50);
    await tester.pumpWidget(
      taggingTestApp(
        harness: pointHarness,
        child: const MarkerRuler(durationMs: 1000, width: 100),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('marker-ruler-marker-point-1')));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(pointHarness.repository.saveCalls, 1);
    expect(
      pointHarness.document.history.single.commands.single.type,
      'update_marker',
    );
    expect(pointHarness.document.currentState.markers.first.atMs, 0);

    final resizedPointHarness = _markerHarness();
    await tester.pumpWidget(
      taggingTestApp(
        harness: resizedPointHarness,
        child: const MarkerRuler(durationMs: 1000, width: 100),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('marker-ruler-marker-point-1')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(resizedPointHarness.repository.saveCalls, 0);
    expect(resizedPointHarness.document.currentState.markers.first.atMs, 200);

    final movedRangeHarness = _markerHarness();
    await tester.pumpWidget(
      taggingTestApp(
        harness: movedRangeHarness,
        child: const MarkerRuler(durationMs: 1000, width: 100),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('marker-ruler-marker-range-1')));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final moved = movedRangeHarness.document.currentState.markers[1];
    expect(movedRangeHarness.repository.saveCalls, 1);
    expect(moved.startMs, 400);
    expect(moved.endMs, 800);

    final rangeHarness = _markerHarness();
    await tester.pumpWidget(
      taggingTestApp(
        harness: rangeHarness,
        child: const MarkerRuler(durationMs: 1000, width: 100),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('marker-ruler-marker-range-1')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    final resized = rangeHarness.document.currentState.markers[1];
    expect(rangeHarness.repository.saveCalls, 1);
    expect(
      rangeHarness.document.history.single.commands.single.type,
      'update_marker',
    );
    expect(resized.startMs, 300);
    expect(resized.endMs, 800);
    expect(resized.endMs!, greaterThan(resized.startMs!));
  });
}

TaggingWidgetHarness _markerHarness({int pointAt = 200}) {
  final base = TaggingWidgetHarness().document;
  return TaggingWidgetHarness(
    document: base.copyWith(
      currentState: ProjectStateSnapshot(
        assets: base.currentState.assets,
        tracks: base.currentState.tracks,
        tags: base.currentState.tags,
        markers: [
          TimelineMarker(
            id: 'point-1',
            label: 'Beat',
            color: '#1299AA',
            atMs: pointAt,
          ),
          const TimelineMarker(
            id: 'range-1',
            label: 'Intro',
            color: '#AA5511',
            startMs: 300,
            endMs: 700,
          ),
        ],
        overlays: base.currentState.overlays,
      ),
    ),
  );
}
