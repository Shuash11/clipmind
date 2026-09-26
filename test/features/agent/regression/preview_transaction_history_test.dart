import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_notifier.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_transaction_gateway.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/project_transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  test(
    'only an approved preview creates one agent transaction history record',
    () async {
      final document = documentWithOneClip();
      final repository = RecordingProjectRepository(document);
      final publisher = RecordingProjectDocumentPublisher();
      final gateway = ProjectTransactionEditPlanGateway(
        service: ProjectTransactionService(
          repository: repository,
          publisher: publisher,
          now: () => fixtureTime,
        ),
        currentDocumentReader: () => repository.document,
      );

      final cancelledPlan = _plan(document, id: 'cancelled-preview');
      final cancelledNotifier = _notifier(gateway, cancelledPlan);
      await cancelledNotifier.submit('Mute the selected clip');
      expect(cancelledNotifier.state.plan, same(cancelledPlan));
      expect(repository.saveCalls, 0);
      expect(repository.document.history, isEmpty);

      cancelledNotifier.cancel(cancelledPlan.id);
      expect(repository.saveCalls, 0);
      expect(repository.document.history, isEmpty);

      final appliedPlan = _plan(document, id: 'approved-preview');
      final notifier = _notifier(gateway, appliedPlan);
      await notifier.submit('Mute the selected clip');
      expect(notifier.state.plan, same(appliedPlan));
      expect(repository.saveCalls, 0);

      notifier.approve(appliedPlan.id);
      expect(notifier.state.plan!.status, EditPlanStatus.approved);
      expect(repository.saveCalls, 0);
      expect(repository.document.history, isEmpty);

      await notifier.apply(appliedPlan.id);

      expect(repository.saveCalls, 1);
      expect(publisher.publishCalls, 1);
      expect(repository.document.history, hasLength(1));
      final history = repository.document.history.single;
      expect(history.planId, appliedPlan.id);
      expect(history.sourceKind, TransactionSourceKind.agent);
      expect(history.beforeState, same(document.currentState));
      expect(history.afterState, same(appliedPlan.payload!.candidateState));
      expect(history.commands, appliedPlan.payload!.summaries);
      expect(repository.document.historyCursor, 0);
      expect(notifier.state.plan!.status, EditPlanStatus.applied);
    },
  );
}

EditPlanNotifier _notifier(EditPlanTransactionGateway gateway, EditPlan plan) =>
    EditPlanNotifier(
      submitter: (command, token) async => Success(plan),
      replanner: (prior, instruction, token) async => Success(plan),
      transactionGateway: gateway,
      cancellationControllerFactory: CancellationController.new,
    );

EditPlan _plan(ProjectDocument document, {required String id}) =>
    EditPlan.valid(
      id: id,
      summary: 'Mute the selected clip',
      baseProjectId: document.id,
      baseRevision: document.revision,
      payload: _payload(),
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
