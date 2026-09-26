import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_providers.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_transaction_gateway.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/edit_transaction.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/agent_chat_panel.dart';

import '../features/projects/support/project_test_data.dart';
import '../features/projects/support/project_fakes.dart';

void main() {
  testWidgets('AgentChatPanel renders suggested prompts when no messages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AgentChatPanel())),
      ),
    );

    expect(find.text('AI Assistant'), findsOneWidget);
    for (final prompt in AgentChatPanel.suggestedPrompts) {
      expect(find.text(prompt), findsOneWidget);
    }
    expect(find.text('Type a command...'), findsOneWidget);
    for (final unsupported in <String>[
      'Add subtitles from speech',
      'Make a highlight reel',
      'speech',
      'automatic analysis',
    ]) {
      expect(AgentChatPanel.suggestedPrompts, isNot(contains(unsupported)));
    }
  });

  testWidgets('AgentChatPanel has send button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AgentChatPanel())),
      ),
    );

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('AgentChatPanel shows configured-empty dynamic model selector', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AgentChatPanel())),
      ),
    );

    expect(
      find.byKey(const ValueKey('dynamic-model-selector')),
      findsOneWidget,
    );
    expect(find.text('Configure AI Providers'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    for (final label in <String>[
      'Flash',
      'Claude (Anthropic)',
      'GPT-4o (OpenAI)',
      'Gemini (Google)',
      'NVIDIA NIM',
    ]) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('submitting creates a preview without an eager transaction', (
    WidgetTester tester,
  ) async {
    var submitCalls = 0;
    final plan = EditPlan.valid(
      id: 'plan-1',
      summary: 'Mute the selected clip',
      baseProjectId: 'project-1',
      baseRevision: 0,
      payload: ValidatedPlanPayload(
        commands: [
          ProjectCommandFactory(
            SequenceIdGenerator(['unused']),
          ).setMuted(clipId: 'clip-1', muted: true),
        ],
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
      ProviderScope(
        overrides: [
          editPlanSubmitterProvider.overrideWithValue((command, token) async {
            submitCalls++;
            return Success(plan);
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: AgentChatPanel())),
      ),
    );

    expect(submitCalls, 0);
    await tester.enterText(find.byType(TextField), 'Mute the selected clip');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    expect(submitCalls, 1);
    expect(find.byKey(const ValueKey('edit-plan-card')), findsOneWidget);
  });

  testWidgets(
    'unavailable composition reports a safe actionable planning state',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: AgentChatPanel())),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Mute the selected clip');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Agent planning is unavailable. Configure an AI provider and try again.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('card Apply and Cancel route only through the plan notifier', (
    WidgetTester tester,
  ) async {
    final document = documentWithOneClip();
    final gateway = _ChatGateway(document);
    final plan = _chatPlan(document);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editPlanSubmitterProvider.overrideWithValue(
            (command, token) async => Success(plan),
          ),
          editPlanTransactionGatewayProvider.overrideWithValue(gateway),
        ],
        child: const MaterialApp(home: Scaffold(body: AgentChatPanel())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Mute the selected clip');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-plan-apply')));
    await tester.pump();
    expect(gateway.applyCalls, 1);

    final cancelGateway = _ChatGateway(document);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editPlanSubmitterProvider.overrideWithValue(
            (command, token) async => Success(_chatPlan(document)),
          ),
          editPlanTransactionGatewayProvider.overrideWithValue(cancelGateway),
        ],
        child: const MaterialApp(home: Scaffold(body: AgentChatPanel())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Mute the selected clip');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-plan-cancel')));
    await tester.pump();
    expect(cancelGateway.applyCalls, 0);
  });

  testWidgets('Revise routes a dialog instruction to one replanning call', (
    WidgetTester tester,
  ) async {
    final document = documentWithOneClip();
    final initial = _chatPlan(document);
    final revised = EditPlan.valid(
      id: 'plan-2',
      summary: 'Use a softer mute change',
      baseProjectId: document.id,
      baseRevision: document.revision,
      payload: _chatPlan(document, id: 'payload-source').payload!,
    );
    final gateway = _ChatGateway(document);
    var replanCalls = 0;
    EditPlan? receivedPrior;
    String? receivedInstruction;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editPlanSubmitterProvider.overrideWithValue(
            (command, token) async => Success(initial),
          ),
          editPlanReplannerProvider.overrideWithValue((
            prior,
            instruction,
            token,
          ) async {
            replanCalls++;
            receivedPrior = prior;
            receivedInstruction = instruction;
            return Success(revised);
          }),
          editPlanTransactionGatewayProvider.overrideWithValue(gateway),
        ],
        child: const MaterialApp(home: Scaffold(body: AgentChatPanel())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Mute the selected clip');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-plan-revise')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('revise-plan-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('revise-plan-instruction')),
      'Use a softer mute change',
    );
    await tester.tap(find.byKey(const ValueKey('revise-plan-submit')));
    await tester.pumpAndSettle();

    expect(replanCalls, 1);
    expect(receivedPrior, same(initial));
    expect(receivedInstruction, 'Use a softer mute change');
    expect(gateway.applyCalls, 0);
    expect(find.byKey(const ValueKey('revise-plan-dialog')), findsNothing);
    expect(find.text('Use a softer mute change'), findsOneWidget);
  });
}

EditPlan _chatPlan(ProjectDocument document, {String id = 'plan-1'}) =>
    EditPlan.valid(
      id: id,
      summary: 'Mute the selected clip',
      baseProjectId: document.id,
      baseRevision: document.revision,
      payload: ValidatedPlanPayload(
        commands: [
          ProjectCommandFactory(
            SequenceIdGenerator(['unused']),
          ).setMuted(clipId: 'clip-1', muted: true),
        ],
        candidateState: stateWithOneClip(muted: true),
        summaries: [
          CanonicalCommandSummary(
            type: 'set_clip_muted',
            targetIds: ['clip-1'],
          ),
        ],
      ),
    );

final class _ChatGateway implements EditPlanTransactionGateway {
  _ChatGateway(this.document);
  final ProjectDocument document;
  var applyCalls = 0;
  @override
  ProjectDocument get currentDocument => document;
  @override
  Future<Result<ProjectSaveOutcome>> apply(
    ProjectDocument expectedDocument,
    EditTransaction transaction,
  ) async {
    applyCalls++;
    return Success(
      ProjectSaveOutcome(
        document: document.copyWith(
          currentState: transaction.candidateState,
          revision: transaction.expectedRevision + 1,
        ),
      ),
    );
  }
}
