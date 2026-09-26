import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_notifier.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_transaction_gateway.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/edit_transaction.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  test(
    'apply has no caller supplied candidate and preserves payload identity',
    () async {
      final document = documentWithOneClip();
      final payload = ValidatedPlanPayload(
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
      );
      final plan = EditPlan.valid(
        id: 'plan-1',
        summary: 'Mute the selected clip',
        baseProjectId: document.id,
        baseRevision: document.revision,
        payload: payload,
      );
      final gateway = _CapturingGateway(document);
      final notifier = EditPlanNotifier(
        submitter: (command, token) async => Success(plan),
        replanner: (prior, instruction, token) async => Success(plan),
        transactionGateway: gateway,
        cancellationControllerFactory: CancellationController.new,
        initialPlan: plan,
      );

      await notifier.apply(plan.id);

      final transaction = gateway.transaction!;
      expect(gateway.preflightDocument, same(document));
      expect(transaction.candidateState, same(payload.candidateState));
      expect(transaction.beforeState, same(document.currentState));
      expect(transaction.expectedRevision, document.revision);
      expect(transaction.commands, orderedEquals(payload.commands));
      expect(transaction.summaries, orderedEquals(payload.summaries));
      expect(transaction.sourceKind, TransactionSourceKind.agent);
    },
  );

  test(
    'stale or cross-project plans and cancel/revise never pass a transaction',
    () async {
      final document = documentWithOneClip(revision: 2);
      final stale = EditPlan.valid(
        id: 'plan-1',
        summary: 'Mute the selected clip',
        baseProjectId: document.id,
        baseRevision: 1,
        payload: _payload(),
      );
      final gateway = _CapturingGateway(document);
      final staleNotifier = _notifier(gateway, stale);
      staleNotifier.approve(stale.id);
      await staleNotifier.apply(stale.id);
      expect(gateway.applyCalls, 0);

      final cross = EditPlan.valid(
        id: 'plan-2',
        summary: 'Mute the selected clip',
        baseProjectId: 'different-project',
        baseRevision: document.revision,
        payload: _payload(),
      );
      final crossNotifier = _notifier(gateway, cross);
      crossNotifier.approve(cross.id);
      await crossNotifier.apply(cross.id);
      crossNotifier.cancel(cross.id);
      await crossNotifier.revise(cross.id, 'Use a safer edit');
      expect(gateway.applyCalls, 0);
    },
  );
}

EditPlanNotifier _notifier(_CapturingGateway gateway, EditPlan plan) =>
    EditPlanNotifier(
      submitter: (command, token) async => Success(plan),
      replanner: (prior, instruction, token) async => Success(plan),
      transactionGateway: gateway,
      cancellationControllerFactory: CancellationController.new,
      initialPlan: plan,
    );

ValidatedPlanPayload _payload() => ValidatedPlanPayload(
  commands: [
    ProjectCommandFactory(
      SequenceIdGenerator(['unused']),
    ).setMuted(clipId: 'clip-1', muted: true),
  ],
  candidateState: stateWithOneClip(muted: true),
  summaries: [
    CanonicalCommandSummary(type: 'set_clip_muted', targetIds: ['clip-1']),
  ],
);

final class _CapturingGateway implements EditPlanTransactionGateway {
  _CapturingGateway(this.document);
  final ProjectDocument document;
  ProjectDocument? preflightDocument;
  EditTransaction? transaction;
  int applyCalls = 0;
  @override
  ProjectDocument get currentDocument => document;
  @override
  Future<Result<ProjectSaveOutcome>> apply(
    ProjectDocument expectedDocument,
    EditTransaction value,
  ) async {
    applyCalls++;
    preflightDocument = expectedDocument;
    transaction = value;
    return Success(
      ProjectSaveOutcome(
        document: document.copyWith(
          currentState: value.candidateState,
          revision: value.expectedRevision + 1,
        ),
      ),
    );
  }
}
