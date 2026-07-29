import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/clip_commands.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_executor.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/edit_transaction.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:clipmind/features/projects/domain/transactions/project_transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';
import '../support/project_test_data.dart';

EditTransaction brightnessTransaction(
  ProjectDocument document, {
  String planId = 'plan-1',
}) {
  const commands = [
    SetClipBrightnessCommand(clipId: 'clip-1', brightness: -0.2),
  ];
  final execution =
      (ProjectCommandExecutor.standard().applyAll(
                document.currentState,
                commands,
              )
              as Success<CommandExecution>)
          .value;
  return EditTransaction(
    planId: planId,
    expectedRevision: document.revision,
    beforeState: document.currentState,
    candidateState: execution.candidateState,
    commands: commands,
    summaries: execution.summaries,
    sourceKind: TransactionSourceKind.agent,
  );
}

EditTransaction multiCommandTransaction(ProjectDocument document) {
  const commands = [
    SetClipBrightnessCommand(clipId: 'clip-1', brightness: -0.2),
    SetClipVolumeCommand(clipId: 'clip-1', volume: 0.5),
  ];
  final execution =
      (ProjectCommandExecutor.standard().applyAll(
                document.currentState,
                commands,
              )
              as Success<CommandExecution>)
          .value;
  return EditTransaction(
    planId: 'plan-multi',
    expectedRevision: document.revision,
    beforeState: document.currentState,
    candidateState: execution.candidateState,
    commands: commands,
    summaries: execution.summaries,
    sourceKind: TransactionSourceKind.agent,
  );
}

void main() {
  ProjectTransactionService service(
    RecordingProjectRepository repository,
    RecordingProjectDocumentPublisher publisher,
  ) => ProjectTransactionService(
    repository: repository,
    publisher: publisher,
    now: () => fixtureTime,
  );

  test('revision mismatch rejects without save or publication', () async {
    final document = documentWithOneClip(revision: 2);
    final repository = RecordingProjectRepository(document);
    final publisher = RecordingProjectDocumentPublisher();
    final stale = brightnessTransaction(documentWithOneClip(revision: 1));
    final result = await service(repository, publisher).apply(document, stale);
    expect(result, isA<Failure<ProjectSaveOutcome>>());
    expect(repository.saveCalls, 0);
    expect(publisher.publishCalls, 0);
  });

  test('multi-command apply creates one durable history record', () async {
    final document = documentWithOneClip();
    final repository = RecordingProjectRepository(document);
    final publisher = RecordingProjectDocumentPublisher();
    final transaction = multiCommandTransaction(document);
    final result = await service(
      repository,
      publisher,
    ).apply(document, transaction);
    final saved = (result as Success<ProjectSaveOutcome>).value.document;
    expect(repository.saveCalls, 1);
    expect(saved.history, hasLength(1));
    expect(saved.history.single.commands, hasLength(2));
    expect(saved.historyCursor, 0);
    expect(saved.revision, 1);
    expect(publisher.document, saved);
  });

  test('undo persists before snapshot and moves history cursor', () async {
    final before = documentWithOneClip();
    final afterState = stateWithOneClip().copyWith(
      overlays: [textOverlayFixture('undo-after')],
    );
    final after = documentWithOneClip(
      revision: 1,
      state: afterState,
      history: [recordFor(before: before.currentState, after: afterState)],
      historyCursor: 0,
    );
    final repository = RecordingProjectRepository(after);
    final publisher = RecordingProjectDocumentPublisher();
    final result = await service(repository, publisher).undo(after);
    final saved = (result as Success<ProjectSaveOutcome>).value.document;
    expect(saved.currentState, before.currentState);
    expect(saved.currentState.overlays, isEmpty);
    expect(saved.historyCursor, -1);
    expect(saved.revision, 2);
  });

  test('redo persists after snapshot and moves history cursor', () async {
    final before = documentWithOneClip();
    final afterState = stateWithOneClip().copyWith(
      overlays: [textOverlayFixture('overlay-1')],
    );
    final undoDocument = documentWithOneClip(
      revision: 2,
      history: [recordFor(before: before.currentState, after: afterState)],
      historyCursor: -1,
    );
    final result = await service(
      RecordingProjectRepository(undoDocument),
      RecordingProjectDocumentPublisher(),
    ).redo(undoDocument);
    final saved = (result as Success<ProjectSaveOutcome>).value.document;
    expect(saved.currentState, afterState);
    expect(saved.historyCursor, 0);
    expect(saved.revision, 3);
  });

  test('new apply truncates redo records', () async {
    final first = recordFor(
      before: stateWithOneClip(),
      after: stateWithOneClip().copyWith(overlays: [textOverlayFixture('old')]),
    );
    final document = documentWithOneClip(history: [first], historyCursor: -1);
    final result = await service(
      RecordingProjectRepository(document),
      RecordingProjectDocumentPublisher(),
    ).apply(document, brightnessTransaction(document, planId: 'replacement'));
    final saved = (result as Success<ProjectSaveOutcome>).value.document;
    expect(saved.history, hasLength(1));
    expect(saved.history.single.planId, 'replacement');
  });

  test('file failure leaves visible document unchanged', () async {
    final document = documentWithOneClip();
    final repository = RecordingProjectRepository(document)..failSave = true;
    final publisher = RecordingProjectDocumentPublisher();
    final result = await service(
      repository,
      publisher,
    ).apply(document, brightnessTransaction(document));
    expect(result, isA<Failure<ProjectSaveOutcome>>());
    expect(publisher.publishCalls, 0);
    expect(repository.document, document);
  });

  test(
    'durable file and index warnings still publish the saved document',
    () async {
      final document = documentWithOneClip();
      final repository = RecordingProjectRepository(document)
        ..nextWarnings = const [
          ProjectFileWarning('rollback_cleanup_failed', 'rollback retained'),
          ProjectIndexWarning(
            'project_index_upsert_failed',
            'index unavailable',
          ),
        ];
      final publisher = RecordingProjectDocumentPublisher();
      final result = await service(
        repository,
        publisher,
      ).apply(document, brightnessTransaction(document));
      expect(result, isA<Success<ProjectSaveOutcome>>());
      expect(publisher.document!.revision, 1);
      expect(
        publisher.warnings.map((ProjectSaveWarning warning) => warning.code),
        ['rollback_cleanup_failed', 'project_index_upsert_failed'],
      );
    },
  );
}
