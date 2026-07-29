import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/presentation/widgets/edit_plan_card.dart';
import 'package:clipmind/features/agent/presentation/widgets/revise_plan_dialog.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_test_data.dart';

void main() {
  testWidgets('card exposes the preview ledger and explicit action controls', (
    tester,
  ) async {
    var applies = 0;
    var cancels = 0;
    var revises = 0;
    final plan = EditPlan.valid(
      id: 'plan-1',
      summary: 'Mute the selected clip',
      baseProjectId: 'project-1',
      baseRevision: 2,
      payload: ValidatedPlanPayload(
        commands: const [],
        candidateState: stateWithOneClip(muted: true),
        summaries: [
          CanonicalCommandSummary(
            type: 'set_clip_muted',
            targetIds: ['clip-1'],
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ClipMindTheme.dark,
        home: Scaffold(
          body: EditPlanCard(
            plan: plan,
            onApply: () => applies++,
            onCancel: () => cancels++,
            onRevise: () => revises++,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('edit-plan-card')), findsOneWidget);
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-plan-apply')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-plan-cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-plan-revise')), findsOneWidget);
    expect(find.textContaining('Set Clip Muted'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-plan-apply')));
    await tester.tap(find.byKey(const ValueKey('edit-plan-cancel')));
    await tester.tap(find.byKey(const ValueKey('edit-plan-revise')));
    expect(applies, 1);
    expect(cancels, 1);
    expect(revises, 1);
  });

  testWidgets(
    'terminal failures are disabled, safe, and warnings remain success',
    (tester) async {
      final preview = _preview(summary: r'C:\private\source.mp4');
      final failed = preview.fail([
        ValidationFinding(
          code: 'apply_failed',
          message: r'failed C:\private\source.mp4',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: ClipMindTheme.dark,
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: EditPlanCard(plan: failed),
              ),
            ),
          ),
        ),
      );
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('No changes were applied.'), findsOneWidget);
      expect(find.textContaining(r'C:\private'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('edit-plan-apply'))).height,
        44,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: ClipMindTheme.dark,
          home: Scaffold(
            body: EditPlanCard(
              plan: preview.apply(),
              saveOutcome: ProjectSaveOutcome(
                document: documentWithOneClip(),
                warnings: const [ProjectFileWarning('index_warning', 'safe')],
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Applied with 1 durable save warning'),
        findsOneWidget,
      );
      expect(find.text('APPLIED'), findsOneWidget);
    },
  );

  testWidgets(
    'revise dialog validates and returns only a revision instruction',
    (tester) async {
      String? instruction;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    RevisePlanDialog(onRevise: (value) => instruction = value),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('revise-plan-instruction')),
        'Keep only the opening',
      );
      await tester.tap(find.byKey(const ValueKey('revise-plan-submit')));
      expect(instruction, 'Keep only the opening');
    },
  );

  testWidgets('revise dialog rejects empty, control, and oversized input', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(home: RevisePlanDialog(onRevise: (_) => calls++)),
    );
    await tester.tap(find.byKey(const ValueKey('revise-plan-submit')));
    await tester.pump();
    expect(
      find.text('Enter a short, safe revision instruction.'),
      findsOneWidget,
    );
    expect(calls, 0);
    await tester.enterText(
      find.byKey(const ValueKey('revise-plan-instruction')),
      'bad\ninput',
    );
    await tester.tap(find.byKey(const ValueKey('revise-plan-submit')));
    await tester.pump();
    expect(
      find.text('Enter a short, safe revision instruction.'),
      findsOneWidget,
    );
    expect(calls, 0);
    await tester.enterText(
      find.byKey(const ValueKey('revise-plan-instruction')),
      'x' * 1001,
    );
    await tester.tap(find.byKey(const ValueKey('revise-plan-submit')));
    await tester.pump();
    expect(
      find.text('Enter a short, safe revision instruction.'),
      findsOneWidget,
    );
    expect(calls, 0);
  });
}

EditPlan _preview({String summary = 'Mute the selected clip'}) =>
    EditPlan.valid(
      id: 'plan-1',
      summary: summary,
      baseProjectId: 'project-1',
      baseRevision: 2,
      payload: ValidatedPlanPayload(
        commands: const [],
        candidateState: stateWithOneClip(muted: true),
        summaries: [
          CanonicalCommandSummary(
            type: 'set_clip_muted',
            targetIds: ['clip-1'],
          ),
        ],
      ),
    );
