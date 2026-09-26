import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/domain/registry/editor_tool_registry.dart';
import 'package:clipmind/features/agent/domain/services/legacy_operation_normalizer.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_notifier.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_transaction_gateway.dart';
import 'package:clipmind/features/projects/domain/transactions/project_transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

void main() {
  test(
    'deferred tools are absent and ambiguous legacy operations cannot mutate a project',
    () async {
      final registry = EditorToolRegistry.standard();
      for (final name in _deferredAliases) {
        expect(registry.byName(name), isNull, reason: name);
      }

      final normalized = LegacyOperationNormalizer().normalize([
        {
          'type': 'cut',
          'targetClipId': 'clip-1',
          'params': {'startMs': 0, 'endMs': 100},
        },
        for (final alias in _deferredAliases)
          <String, Object?>{'type': alias, 'params': <String, Object?>{}},
      ]);

      expect(normalized.calls, isEmpty);
      expect(
        normalized.findings.map((finding) => finding.code),
        contains('ambiguous_legacy_operation'),
      );
      expect(
        normalized.findings.where(
          (finding) => finding.code == 'unsupported_legacy_operation',
        ),
        hasLength(_deferredAliases.length),
      );

      final document = documentWithOneClip();
      final repository = RecordingProjectRepository(document);
      final publisher = RecordingProjectDocumentPublisher();
      final notifier = EditPlanNotifier(
        submitter: (command, token) async => Success(
          EditPlan.rejected(
            id: 'legacy-rejected',
            summary: 'Legacy operation was rejected.',
            baseProjectId: document.id,
            baseRevision: document.revision,
            findings: normalized.findings,
          ),
        ),
        replanner: (prior, instruction, token) async => Success(prior),
        transactionGateway: ProjectTransactionEditPlanGateway(
          service: ProjectTransactionService(
            repository: repository,
            publisher: publisher,
            now: () => fixtureTime,
          ),
          currentDocumentReader: () => repository.document,
        ),
        cancellationControllerFactory: CancellationController.new,
      );

      await notifier.submit('Cut the selected clip');
      expect(notifier.state.plan!.findings, isNotEmpty);
      expect(notifier.state.plan!.payload, isNull);
      await notifier.apply(notifier.state.plan!.id);

      expect(repository.saveCalls, 0);
      expect(publisher.publishCalls, 0);
      expect(repository.document, same(document));
      expect(repository.document.history, isEmpty);
    },
  );
}

const _deferredAliases = <String>[
  'extract_audio',
  'generate_thumbnail',
  'change_format',
  'merge',
];
