import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:clipmind/state/project_command_gateway_providers.dart';

import '../../features/tagging/support/tagging_widget_harness.dart';

void main() {
  test(
    'agent commands persist an agent transaction with revision + undo/redo',
    () async {
      final harness = TaggingWidgetHarness();
      final container = ProviderContainer.test(
        overrides: [
          taggingProvidersProvider.overrideWithValue(harness.providers),
        ],
      );
      addTearDown(container.dispose);

      final gateway = container.read(projectCommandGatewayProvider)!;
      expect(gateway.snapshot(), same(harness.document.currentState));

      final command =
          harness.controller.createTag(name: 'Music', color: '#AABBCC');
      final result = await gateway.applyCommands([command]);

      // Gateway surfaces the validated execution (candidate + summaries).
      final execution = (result as Success<CommandExecution>).value;
      expect(execution.summaries.single.type, 'create_tag');
      expect(execution.summaries.single.targetIds, [command.tagId]);
      expect(execution.candidateState.tags.last.name, 'Music');

      // Same persistence path as manual tagging: one save + one publish.
      expect(harness.repository.saveCalls, 1);
      expect(harness.publisher.publishCalls, 1);
      expect(harness.document.revision, 1);
      final record = harness.document.history.single;
      expect(record.sourceKind, TransactionSourceKind.agent);
      expect(record.commands.single.type, 'create_tag');
      expect(harness.document.currentState.tags.last.name, 'Music');
      // The reader sees the updated snapshot afterwards.
      expect(
        gateway.snapshot()!.tags.map((tag) => tag.name),
        contains('Music'),
      );

      // Undo restores the pre-command state; redo re-applies it.
      final undone = await harness.transactions.undo(harness.document);
      expect(undone, isA<Success<ProjectSaveOutcome>>());
      expect(harness.document.revision, 2);
      expect(
        harness.document.currentState.tags.map((tag) => tag.name),
        isNot(contains('Music')),
      );

      final redone = await harness.transactions.redo(harness.document);
      expect(redone, isA<Success<ProjectSaveOutcome>>());
      expect(harness.document.revision, 3);
      expect(
        harness.document.currentState.tags.map((tag) => tag.name),
        contains('Music'),
      );
    },
  );

  test('agent and manual paths produce the same state and persistence',
      () async {
    final manual = TaggingWidgetHarness();
    final manualResult = await manual.providers.applyManual(
      manual.controller.createTag(name: 'Music', color: '#AABBCC'),
    );
    expect(manualResult, isA<Success<ProjectSaveOutcome>>());

    final agent = TaggingWidgetHarness();
    final container = ProviderContainer.test(
      overrides: [
        taggingProvidersProvider.overrideWithValue(agent.providers),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(projectCommandGatewayProvider)!
        .applyCommands([agent.controller.createTag(name: 'Music', color: '#AABBCC')]);

    // Identical fixture + command ID sequence → identical results; only
    // the recorded source kind differs.
    expect(agent.document.currentState, manual.document.currentState);
    expect(agent.document.revision, manual.document.revision);
    expect(agent.repository.saveCalls, manual.repository.saveCalls);
    expect(agent.publisher.publishCalls, manual.publisher.publishCalls);
    expect(
      manual.document.history.single.sourceKind,
      TransactionSourceKind.manual,
    );
    expect(
      agent.document.history.single.sourceKind,
      TransactionSourceKind.agent,
    );
  });

  test('persistence failures surface through the gateway', () async {
    final harness = TaggingWidgetHarness();
    harness.repository.failSave = true;
    final container = ProviderContainer.test(
      overrides: [
        taggingProvidersProvider.overrideWithValue(harness.providers),
      ],
    );
    addTearDown(container.dispose);
    final gateway = container.read(projectCommandGatewayProvider)!;

    final result = await gateway.applyCommands([
      harness.controller.createTag(name: 'Music', color: '#AABBCC'),
    ]);

    expect(result, isA<Failure<CommandExecution>>());
    expect(
      (result as Failure<CommandExecution>).error.message,
      contains('disk unavailable'),
    );
    expect(harness.repository.saveCalls, 1);
    expect(harness.publisher.publishCalls, 0);
    expect(harness.document.history, isEmpty);
    expect(harness.document.revision, 0);
  });

  test('no tagging wiring degrades to a null gateway', () {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    expect(container.read(projectCommandGatewayProvider), isNull);
  });
}
