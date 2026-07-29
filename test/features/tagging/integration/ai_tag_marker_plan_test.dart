import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/presentation/widgets/edit_plan_card.dart';
import 'package:clipmind/features/agent/presentation/widgets/edit_plan_operation_row.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  testWidgets(
    'tag deletion preview shows handler-derived assignments and cancels cleanly',
    (tester) async {
      final before = stateWithOneClip();
      final command = ProjectCommandFactory(
        SequenceIdGenerator(['unused']),
      ).deleteTag(tagId: 'tag-1');
      final execution = ProjectCommandExecutor.standard().applyAll(before, [
        command,
      ]);

      expect(execution, isA<Success<CommandExecution>>());
      final candidate = (execution as Success<CommandExecution>).value;
      expect(candidate.candidateState.tags, isEmpty);
      expect(candidate.candidateState.assets.single.tagIds, isEmpty);
      expect(
        candidate.candidateState.tracks.single.clips.single.tagIds,
        isEmpty,
      );
      expect(candidate.summaries, hasLength(1));
      expect(candidate.summaries.single.type, 'delete_tag');
      expect(
        candidate.summaries.single.targetIds,
        orderedEquals(['tag-1', 'asset-1', 'clip-1']),
      );

      final plan = EditPlan.valid(
        id: 'delete-travel-tag',
        summary: 'Delete Travel without changing any assignments.',
        baseProjectId: 'project-1',
        baseRevision: 0,
        payload: ValidatedPlanPayload(
          commands: [command],
          candidateState: candidate.candidateState,
          summaries: candidate.summaries,
        ),
      );
      var transactionCalls = 0;
      var cancelCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ClipMindTheme.dark,
          home: Scaffold(
            body: EditPlanCard(
              plan: plan,
              onApply: () => transactionCalls++,
              onCancel: () => cancelCalls++,
            ),
          ),
        ),
      );

      expect(find.byType(EditPlanOperationRow), findsOneWidget);
      expect(find.textContaining('Delete Tag'), findsOneWidget);
      expect(find.textContaining('asset-1'), findsOneWidget);
      expect(find.textContaining('clip-1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('edit-plan-cancel')));

      expect(cancelCalls, 1);
      expect(transactionCalls, 0);
    },
  );
}
