import 'package:clipmind/features/projects/domain/commands/clip_commands.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/entities/timeline_marker.dart';
import 'package:clipmind/features/projects/presentation/timeline_project_controller.dart';
import 'package:clipmind/features/tagging/presentation/widgets/marker_ruler.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';
import '../support/tagging_widget_harness.dart';

void main() {
  testWidgets(
    'removes the explicit selected clip-local range once via transaction bridge',
    (tester) async {
      final gateway = RecordingProjectTransactionGateway();
      final controller = TimelineProjectController(
        factory: ProjectCommandFactory(SequenceIdGenerator(['right-clip'])),
        transactions: gateway,
        document: documentWithOneClip(),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TimelineView(
                selectedRange: const TimelineClipRange(
                  clipId: 'clip-1',
                  startMs: 125,
                  endMs: 375,
                ),
                onRemoveRange: controller.removeRange,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Remove selected range'));
      await tester.pumpAndSettle();

      expect(gateway.transactions, hasLength(1));
      final transaction = gateway.transactions.single;
      expect(transaction.sourceKind.name, 'manual');
      final command = transaction.commands.single as RemoveClipRangeCommand;
      expect(command.clipId, 'clip-1');
      expect(command.startMs, 125);
      expect(command.endMs, 375);
      expect(command.rightClipId, 'right-clip');
      expect(gateway.directRepositorySaves, 0);
    },
  );

  testWidgets(
    'renders canonical marker ruler entries without creating transactions',
    (tester) async {
      final base = TaggingWidgetHarness().document;
      final harness = TaggingWidgetHarness(
        document: base.copyWith(
          currentState: base.currentState.copyWith(
            markers: const [
              TimelineMarker(
                id: 'point-1',
                label: 'Beat',
                color: '#1299AA',
                atMs: 200,
              ),
              TimelineMarker(
                id: 'range-1',
                label: 'Intro',
                color: '#AA5511',
                startMs: 300,
                endMs: 700,
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        taggingTestApp(
          harness: harness,
          child: const SizedBox(
            width: 1000,
            height: 600,
            child: TimelineView(),
          ),
        ),
      );

      expect(find.byType(MarkerRuler), findsOneWidget);
      expect(
        find.byKey(const ValueKey('marker-ruler-marker-point-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('marker-ruler-marker-range-1')),
        findsOneWidget,
      );
      expect(harness.repository.saveCalls, 0);
      expect(harness.publisher.publishCalls, 0);
    },
  );
}
