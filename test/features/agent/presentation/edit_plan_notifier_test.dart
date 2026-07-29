import 'dart:async';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/entities/validated_plan_payload.dart';
import 'package:clipmind/features/agent/domain/entities/validation_finding.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_notifier.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_transaction_gateway.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/edit_transaction.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:clipmind/features/projects/domain/transactions/project_transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  test(
    'submit previews and apply uses the exact validated payload once',
    () async {
      final document = documentWithOneClip(revision: 4);
      final payload = _payload();
      final plan = EditPlan.valid(
        id: 'plan-1',
        summary: 'Mute the selected clip',
        baseProjectId: document.id,
        baseRevision: document.revision,
        payload: payload,
      );
      final gateway = _Gateway(document);
      final notifier = _notifier(gateway, plan);

      await notifier.submit('Mute the selected clip');
      expect(notifier.state.plan, same(plan));
      expect(gateway.applyCalls, 0);

      await notifier.apply(plan.id);

      expect(gateway.applyCalls, 1);
      expect(notifier.state.plan!.status, EditPlanStatus.applied);
      expect(gateway.transaction!.planId, plan.id);
      expect(gateway.transaction!.expectedRevision, document.revision);
      expect(gateway.transaction!.beforeState, same(document.currentState));
      expect(gateway.transaction!.candidateState, same(payload.candidateState));
      expect(gateway.transaction!.commands, payload.commands);
      expect(gateway.transaction!.summaries, payload.summaries);
    },
  );

  test(
    'stale and wrong plan apply calls never reach the transaction gateway',
    () async {
      final document = documentWithOneClip(revision: 1);
      final plan = EditPlan.valid(
        id: 'plan-1',
        summary: 'Mute the selected clip',
        baseProjectId: document.id,
        baseRevision: 0,
        payload: _payload(),
      );
      final gateway = _Gateway(document);
      final notifier = _notifier(gateway, plan);

      await notifier.apply('other-plan');
      expect(gateway.applyCalls, 0);
      await notifier.apply(plan.id);
      expect(gateway.applyCalls, 0);
      expect(notifier.state.plan!.status, EditPlanStatus.failed);
      expect(notifier.state.plan!.payload, isNotNull);
    },
  );

  test('cancel clears a preview without saving', () {
    final document = documentWithOneClip();
    final plan = EditPlan.valid(
      id: 'plan-1',
      summary: 'Mute the selected clip',
      baseProjectId: document.id,
      baseRevision: document.revision,
      payload: _payload(),
    );
    final gateway = _Gateway(document);
    final notifier = _notifier(gateway, plan);

    notifier.cancel(plan.id);

    expect(notifier.state.plan!.status, EditPlanStatus.cancelled);
    expect(notifier.state.plan!.payload, isNull);
    expect(gateway.applyCalls, 0);
  });

  test(
    'approve is persistence-free and apply accepts the approved preview',
    () async {
      final document = documentWithOneClip();
      final plan = _plan(document);
      final gateway = _Gateway(document);
      final notifier = _notifier(gateway, plan);

      notifier.approve(plan.id);
      expect(notifier.state.plan!.status, EditPlanStatus.approved);
      expect(gateway.applyCalls, 0);
      await notifier.apply(plan.id);

      expect(gateway.applyCalls, 1);
      expect(notifier.state.plan!.status, EditPlanStatus.applied);
    },
  );

  test(
    'cross-project, missing-document, and malformed success never apply',
    () async {
      final document = documentWithOneClip();
      final crossProject = EditPlan.valid(
        id: 'plan-1',
        summary: 'Mute the selected clip',
        baseProjectId: 'another-project',
        baseRevision: document.revision,
        payload: _payload(),
      );
      final crossGateway = _Gateway(document);
      final crossNotifier = _notifier(crossGateway, crossProject);
      crossNotifier.approve(crossProject.id);
      await crossNotifier.apply(crossProject.id);
      expect(crossGateway.applyCalls, 0);
      expect(crossNotifier.state.plan!.status, EditPlanStatus.failed);

      final missingGateway = _NullableGateway();
      final missingNotifier = EditPlanNotifier(
        submitter: (command, token) async => Success(_plan(document)),
        replanner: (prior, instruction, token) async =>
            Success(_plan(document)),
        transactionGateway: missingGateway,
        cancellationControllerFactory: CancellationController.new,
        initialPlan: _plan(document),
      );
      missingNotifier.approve('plan-1');
      await missingNotifier.apply('plan-1');
      expect(missingGateway.applyCalls, 0);
      expect(missingNotifier.state.plan!.status, EditPlanStatus.failed);

      final malformedGateway = _Gateway(document)..coherentOutcome = false;
      final malformedNotifier = _notifier(malformedGateway, _plan(document));
      await malformedNotifier.apply('plan-1');
      expect(malformedGateway.applyCalls, 1);
      expect(malformedNotifier.state.plan!.status, EditPlanStatus.failed);
      expect(malformedNotifier.state.plan!.payload, isNotNull);
    },
  );

  test(
    'concurrent and repeated apply invoke the gateway exactly once',
    () async {
      final document = documentWithOneClip();
      final gateway = _BlockingGateway(document);
      final notifier = EditPlanNotifier(
        submitter: (command, token) async => Success(_plan(document)),
        replanner: (prior, instruction, token) async =>
            Success(_plan(document)),
        transactionGateway: gateway,
        cancellationControllerFactory: CancellationController.new,
        initialPlan: _plan(document),
      );

      final first = notifier.apply('plan-1');
      final second = notifier.apply('plan-1');
      expect(gateway.applyCalls, 1);
      gateway.complete();
      await Future.wait([first, second]);
      await notifier.apply('plan-1');
      expect(gateway.applyCalls, 1);
    },
  );

  test('cancel active planning and revise suppress late results', () async {
    final submit = Completer<Result<EditPlan>>();
    final document = documentWithOneClip();
    final gateway = _Gateway(document);
    final notifier = EditPlanNotifier(
      submitter: (command, token) => submit.future,
      replanner: (prior, instruction, token) async => Success(_plan(document)),
      transactionGateway: gateway,
      cancellationControllerFactory: CancellationController.new,
    );

    final pending = notifier.submit('Mute the selected clip');
    notifier.cancelActivePlanning();
    submit.complete(Success(_plan(document)));
    await pending;
    expect(notifier.state.plan, isNull);
    expect(gateway.applyCalls, 0);

    final old = _plan(document);
    final revised = _plan(document, id: 'plan-2');
    final reviser = EditPlanNotifier(
      submitter: (command, token) async => Success(old),
      replanner: (prior, instruction, token) async => Success(revised),
      transactionGateway: gateway,
      cancellationControllerFactory: CancellationController.new,
      initialPlan: old,
    );
    await reviser.revise(old.id, 'Use a softer change');
    expect(reviser.state.priorRevisedPlans, hasLength(1));
    expect(
      reviser.state.priorRevisedPlans.single.status,
      EditPlanStatus.revised,
    );
    expect(reviser.state.plan!.id, 'plan-2');
    expect(gateway.applyCalls, 0);
  });

  test(
    'submit accepts only safe planning statuses and never saves them',
    () async {
      final document = documentWithOneClip();
      final valid = _plan(document);
      final rejected = EditPlan.rejected(
        id: 'rejected-plan',
        summary: 'The preview was rejected.',
        baseProjectId: document.id,
        baseRevision: document.revision,
        findings: [
          ValidationFinding(code: 'invalid_plan', message: 'Invalid plan.'),
        ],
      );
      final failed = EditPlan.failedBeforeValidation(
        id: 'failed-plan',
        summary: 'The preview failed.',
        baseProjectId: document.id,
        baseRevision: document.revision,
      );
      for (final plan in [valid, rejected, failed]) {
        final gateway = _Gateway(document);
        final notifier = EditPlanNotifier(
          submitter: (command, token) async => Success(plan),
          replanner: (prior, instruction, token) async => Success(plan),
          transactionGateway: gateway,
          cancellationControllerFactory: CancellationController.new,
        );
        await notifier.submit('Mute the selected clip');
        expect(notifier.state.plan, same(plan));
        expect(gateway.applyCalls, 0);
      }

      final invalidStatuses = <EditPlan>[
        EditPlan.draft(
          id: 'draft-plan',
          summary: 'Draft',
          baseProjectId: document.id,
          baseRevision: document.revision,
        ),
        valid.approve(),
        valid.apply(),
        valid.cancel(),
        valid.revise(),
      ];
      for (final plan in invalidStatuses) {
        final notifier = EditPlanNotifier(
          submitter: (command, token) async => Success(plan),
          replanner: (prior, instruction, token) async => Success(plan),
          transactionGateway: _Gateway(document),
          cancellationControllerFactory: CancellationController.new,
        );
        await notifier.submit('Mute the selected clip');
        expect(notifier.state.plan, isNull);
        expect(notifier.state.failureMessage, isNotNull);
      }
    },
  );

  test(
    'revise rejects untrusted result identity, status, and payload',
    () async {
      final document = documentWithOneClip();
      final statusSource = _plan(document, id: 'status-source');
      final untrusted = <EditPlan Function(EditPlan)>[
        (old) => _plan(document, id: old.id),
        (_) => EditPlan.valid(
          id: 'plan-2',
          summary: 'Wrong project',
          baseProjectId: 'other-project',
          baseRevision: document.revision,
          payload: _payload(),
        ),
        (_) => EditPlan.valid(
          id: 'plan-2',
          summary: 'Stale revision',
          baseProjectId: document.id,
          baseRevision: document.revision + 1,
          payload: _payload(),
        ),
        (old) => EditPlan.valid(
          id: 'plan-2',
          summary: 'Reused payload',
          baseProjectId: document.id,
          baseRevision: document.revision,
          payload: old.payload!,
        ),
        (_) => EditPlan.draft(
          id: 'plan-2',
          summary: 'Draft',
          baseProjectId: document.id,
          baseRevision: document.revision,
        ),
        (_) => statusSource.approve(),
        (_) => statusSource.apply(),
        (_) => statusSource.cancel(),
        (_) => statusSource.revise(),
      ];

      for (final createResult in untrusted) {
        final old = _plan(document);
        final gateway = _Gateway(document);
        final notifier = EditPlanNotifier(
          submitter: (command, token) async => Success(old),
          replanner: (prior, instruction, token) async =>
              Success(createResult(old)),
          transactionGateway: gateway,
          cancellationControllerFactory: CancellationController.new,
          initialPlan: old,
        );

        await notifier.revise(old.id, 'Use a safer change');

        expect(gateway.applyCalls, 0);
        expect(notifier.state.priorRevisedPlans, hasLength(1));
        expect(
          notifier.state.priorRevisedPlans.single.status,
          EditPlanStatus.revised,
        );
        expect(notifier.state.plan!.status, EditPlanStatus.failed);
        expect(notifier.state.plan!.payload, isNull);
        expect(notifier.state.plan!.status, isNot(EditPlanStatus.applied));
        expect(notifier.state.plan!.status, isNot(EditPlanStatus.approved));
      }
    },
  );

  test(
    'revise handles failures and safe rejected or failed outcomes',
    () async {
      final document = documentWithOneClip();
      for (final replanner in <EditPlanReplanner>[
        (prior, instruction, token) async => const Failure<EditPlan>(
          ProjectValidationFailure('REVISION_SENTINEL'),
        ),
        (prior, instruction, token) async =>
            throw StateError('REVISION_SENTINEL'),
      ]) {
        final old = _plan(document);
        final gateway = _Gateway(document);
        final notifier = EditPlanNotifier(
          submitter: (command, token) async => Success(old),
          replanner: replanner,
          transactionGateway: gateway,
          cancellationControllerFactory: CancellationController.new,
          initialPlan: old,
        );
        await notifier.revise(old.id, 'Use a safer change');
        expect(notifier.state.plan!.status, EditPlanStatus.failed);
        expect(
          notifier.state.failureMessage,
          isNot(contains('REVISION_SENTINEL')),
        );
        expect(notifier.state.priorRevisedPlans, hasLength(1));
        expect(gateway.applyCalls, 0);
      }

      final accepted = <EditPlan>[
        EditPlan.rejected(
          id: 'rejected-revision',
          summary: 'Rejected revision',
          baseProjectId: document.id,
          baseRevision: document.revision,
          findings: [
            ValidationFinding(code: 'invalid_plan', message: 'Invalid plan.'),
          ],
        ),
        EditPlan.failedBeforeValidation(
          id: 'failed-revision',
          summary: 'Failed revision',
          baseProjectId: document.id,
          baseRevision: document.revision,
        ),
      ];
      for (final result in accepted) {
        final old = _plan(document);
        final gateway = _Gateway(document);
        final notifier = EditPlanNotifier(
          submitter: (command, token) async => Success(old),
          replanner: (prior, instruction, token) async => Success(result),
          transactionGateway: gateway,
          cancellationControllerFactory: CancellationController.new,
          initialPlan: old,
        );
        await notifier.revise(old.id, 'Use a safer change');
        expect(notifier.state.plan, same(result));
        expect(notifier.state.priorRevisedPlans, hasLength(1));
        expect(gateway.applyCalls, 0);
      }
    },
  );

  test(
    'dispose cancels owned planning and ignores a late completion',
    () async {
      final completion = Completer<Result<EditPlan>>();
      final document = documentWithOneClip();
      CancellationToken? captured;
      final gateway = _Gateway(document);
      final notifier = EditPlanNotifier(
        submitter: (command, token) {
          captured = token;
          return completion.future;
        },
        replanner: (prior, instruction, token) async =>
            Success(_plan(document)),
        transactionGateway: gateway,
        cancellationControllerFactory: CancellationController.new,
      );

      final pending = notifier.submit('Mute the selected clip');
      notifier.dispose();
      expect(captured!.isCancelled, isTrue);
      completion.complete(Success(_plan(document)));
      await pending;
      expect(gateway.applyCalls, 0);
    },
  );

  test(
    'independent revision sessions receive fresh cancellation tokens',
    () async {
      final document = documentWithOneClip();
      final tokens = <CancellationToken>[];
      var replans = 0;
      Future<void> runSession(String nextId) async {
        final old = _plan(document);
        final notifier = EditPlanNotifier(
          submitter: (command, token) async => Success(old),
          replanner: (prior, instruction, token) async {
            replans++;
            tokens.add(token);
            return Success(_plan(document, id: nextId));
          },
          transactionGateway: _Gateway(document),
          cancellationControllerFactory: CancellationController.new,
          initialPlan: old,
        );
        await notifier.revise(old.id, 'Use a safer change');
      }

      await runSession('plan-2');
      await runSession('plan-3');
      expect(replans, 2);
      expect(tokens, hasLength(2));
      expect(identical(tokens[0], tokens[1]), isFalse);
      expect(tokens.every((token) => !token.isCancelled), isTrue);
    },
  );

  test(
    'real project transaction persists before publishing and retains failure payload',
    () async {
      final document = documentWithOneClip();
      final repository = RecordingProjectRepository(document)
        ..nextWarnings = const [
          ProjectFileWarning('index_warning', 'Index delayed.'),
        ];
      final publisher = RecordingProjectDocumentPublisher();
      final service = ProjectTransactionService(
        repository: repository,
        publisher: publisher,
        now: () => fixtureTime,
      );
      final gateway = ProjectTransactionEditPlanGateway(
        service: service,
        currentDocumentReader: () => document,
      );
      final plan = _plan(document);
      final notifier = EditPlanNotifier(
        submitter: (command, token) async => Success(plan),
        replanner: (prior, instruction, token) async => Success(plan),
        transactionGateway: gateway,
        cancellationControllerFactory: CancellationController.new,
        initialPlan: plan,
      );

      expect(repository.saveCalls, 0);
      notifier.cancel('wrong-plan');
      expect(publisher.publishCalls, 0);
      await notifier.apply(plan.id);
      expect(repository.saveCalls, 1);
      expect(publisher.publishCalls, 1);
      expect(repository.document.revision, 1);
      expect(repository.document.history, hasLength(1));
      expect(repository.document.history.single.planId, plan.id);
      expect(
        repository.document.history.single.sourceKind,
        TransactionSourceKind.agent,
      );
      expect(
        repository.document.history.single.beforeState,
        same(document.currentState),
      );
      expect(
        repository.document.history.single.afterState,
        same(plan.payload!.candidateState),
      );
      expect(
        repository.document.history.single.commands,
        plan.payload!.summaries,
      );
      expect(repository.document.historyCursor, 0);
      expect(notifier.state.plan!.status, EditPlanStatus.applied);
      expect(notifier.state.saveOutcome!.warnings, hasLength(1));
      expect(publisher.warnings, hasLength(1));

      final failedRepository = RecordingProjectRepository(document)
        ..failSave = true;
      final failedPublisher = RecordingProjectDocumentPublisher();
      final failedNotifier = EditPlanNotifier(
        submitter: (command, token) async => Success(_plan(document)),
        replanner: (prior, instruction, token) async =>
            Success(_plan(document)),
        transactionGateway: ProjectTransactionEditPlanGateway(
          service: ProjectTransactionService(
            repository: failedRepository,
            publisher: failedPublisher,
            now: () => fixtureTime,
          ),
          currentDocumentReader: () => document,
        ),
        cancellationControllerFactory: CancellationController.new,
        initialPlan: _plan(document),
      );
      await failedNotifier.apply('plan-1');
      expect(failedRepository.saveCalls, 1);
      expect(failedPublisher.publishCalls, 0);
      expect(failedNotifier.state.plan!.status, EditPlanStatus.failed);
      expect(failedNotifier.state.plan!.payload, isNotNull);
    },
  );

  test(
    'stateless gateway rejects a project switch after notifier preflight',
    () async {
      final projectA = documentWithOneClip();
      final projectB = documentWithOneClip(revision: 1);
      final repository = RecordingProjectRepository(projectA);
      final publisher = RecordingProjectDocumentPublisher();
      var reads = 0;
      final gateway = ProjectTransactionEditPlanGateway(
        service: ProjectTransactionService(
          repository: repository,
          publisher: publisher,
          now: () => fixtureTime,
        ),
        currentDocumentReader: () => reads++ == 0 ? projectA : projectB,
      );
      final plan = _plan(projectA);
      final notifier = EditPlanNotifier(
        submitter: (command, token) async => Success(plan),
        replanner: (prior, instruction, token) async => Success(plan),
        transactionGateway: gateway,
        cancellationControllerFactory: CancellationController.new,
        initialPlan: plan,
      );

      await notifier.apply(plan.id);

      expect(repository.saveCalls, 0);
      expect(publisher.publishCalls, 0);
      expect(notifier.state.plan!.status, EditPlanStatus.failed);
      expect(notifier.state.plan!.payload, same(plan.payload));
    },
  );
}

EditPlanNotifier _notifier(_Gateway gateway, EditPlan plan) => EditPlanNotifier(
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

EditPlan _plan(ProjectDocument document, {String id = 'plan-1'}) =>
    EditPlan.valid(
      id: id,
      summary: 'Mute the selected clip',
      baseProjectId: document.id,
      baseRevision: document.revision,
      payload: _payload(),
    );

final class _Gateway implements EditPlanTransactionGateway {
  _Gateway(this.document);
  final ProjectDocument document;
  EditTransaction? transaction;
  int applyCalls = 0;
  bool coherentOutcome = true;

  @override
  ProjectDocument get currentDocument => document;

  @override
  Future<Result<ProjectSaveOutcome>> apply(
    ProjectDocument expectedDocument,
    EditTransaction value,
  ) async {
    applyCalls++;
    transaction = value;
    final outcome = coherentOutcome
        ? document.copyWith(
            currentState: value.candidateState,
            revision: value.expectedRevision + 1,
          )
        : document;
    return Success(ProjectSaveOutcome(document: outcome));
  }
}

final class _NullableGateway implements EditPlanTransactionGateway {
  var applyCalls = 0;
  @override
  ProjectDocument? get currentDocument => null;
  @override
  Future<Result<ProjectSaveOutcome>> apply(
    ProjectDocument expectedDocument,
    EditTransaction transaction,
  ) async {
    applyCalls++;
    return const Failure(ProjectValidationFailure('Unavailable'));
  }
}

final class _BlockingGateway implements EditPlanTransactionGateway {
  _BlockingGateway(this.document);
  final ProjectDocument document;
  final _result = Completer<Result<ProjectSaveOutcome>>();
  var applyCalls = 0;
  EditTransaction? transaction;
  @override
  ProjectDocument get currentDocument => document;
  @override
  Future<Result<ProjectSaveOutcome>> apply(
    ProjectDocument expectedDocument,
    EditTransaction value,
  ) {
    applyCalls++;
    transaction = value;
    return _result.future;
  }

  void complete() => _result.complete(
    Success(
      ProjectSaveOutcome(
        document: document.copyWith(
          currentState: transaction!.candidateState,
          revision: transaction!.expectedRevision + 1,
        ),
      ),
    ),
  );
}
