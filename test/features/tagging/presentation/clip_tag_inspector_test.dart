import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/tag_commands.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:clipmind/features/tagging/presentation/widgets/clip_tag_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tagging_widget_harness.dart';

void main() {
  testWidgets('removes an assigned clip tag through one manual transaction', (
    tester,
  ) async {
    final harness = TaggingWidgetHarness();
    await tester.pumpWidget(
      taggingTestApp(
        harness: harness,
        child: const ClipTagInspector(clipId: 'clip-1'),
      ),
    );

    final control = find.bySemanticsLabel('Remove tag Travel from clip clip-1');
    expect(control, findsOneWidget);
    await tester.tap(control);
    await tester.pumpAndSettle();

    expect(harness.repository.saveCalls, 1);
    expect(harness.publisher.publishCalls, 1);
    final record = harness.document.history.single;
    expect(record.sourceKind, TransactionSourceKind.manual);
    expect(record.commands.single.type, 'unassign_tag');
    expect(
      harness.document.currentState.tracks.single.clips.single.tagIds,
      isEmpty,
    );
  });

  testWidgets('assigns an available tag once and rejects assignment no-ops', (
    tester,
  ) async {
    final withoutTag = TaggingWidgetHarness(
      document: TaggingWidgetHarness().document.copyWith(
        currentState: _stateWithClipTags(const {}),
      ),
    );
    await tester.pumpWidget(
      taggingTestApp(
        harness: withoutTag,
        child: const ClipTagInspector(clipId: 'clip-1'),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Add tag Travel to clip clip-1'));
    await tester.pumpAndSettle();
    expect(withoutTag.repository.saveCalls, 1);
    expect(
      withoutTag.document.history.single.commands.single.type,
      'assign_tag',
    );
    expect(
      withoutTag.document.history.single.sourceKind,
      TransactionSourceKind.manual,
    );

    final duplicate = TaggingWidgetHarness();
    await tester.pumpWidget(
      taggingTestApp(
        harness: duplicate,
        child: const ClipTagInspector(clipId: 'clip-1'),
      ),
    );
    expect(
      find.bySemanticsLabel('Add tag Travel to clip clip-1'),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Remove tag Travel from clip clip-1'),
      findsOneWidget,
    );
    final result = await duplicate.providers.applyManual(
      duplicate.controller.assignTag(
        tagId: 'tag-1',
        targetKind: AssignmentTargetKind.clip,
        targetId: 'clip-1',
      ),
    );
    expect(result, isA<Failure<ProjectSaveOutcome>>());
    expect(duplicate.repository.saveCalls, 0);
    expect(duplicate.publisher.publishCalls, 0);
  });

  testWidgets('does not persist when the selected clip is unavailable', (
    tester,
  ) async {
    final harness = TaggingWidgetHarness();
    await tester.pumpWidget(
      taggingTestApp(
        harness: harness,
        child: const ClipTagInspector(clipId: 'missing-clip'),
      ),
    );
    expect(find.text('Clip unavailable'), findsOneWidget);
    expect(harness.repository.saveCalls, 0);
  });
}

ProjectStateSnapshot _stateWithClipTags(Set<String> tagIds) {
  final base = TaggingWidgetHarness().document.currentState;
  final track = base.tracks.single;
  return base.copyWith(
    tracks: [
      track.copyWith(clips: [track.clips.single.copyWith(tagIds: tagIds)]),
    ],
  );
}
