import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/transactions/project_document_publisher.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:clipmind/features/projects/domain/transactions/project_transaction_service.dart';
import 'package:clipmind/features/tagging/domain/tagging_controller.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/support/project_fakes.dart';
import '../../projects/support/project_test_data.dart';

final class TaggingWidgetHarness {
  TaggingWidgetHarness({
    ProjectDocument? document,
    Iterable<String> commandIds = const [
      'created-tag',
      'created-marker',
      'created-marker-2',
    ],
    Iterable<String> transactionIds = const [
      'manual-1',
      'manual-2',
      'manual-3',
      'manual-4',
      'manual-5',
    ],
  }) : document = document ?? documentWithOneClip() {
    repository = RecordingProjectRepository(this.document);
    publisher = UpdatingProjectDocumentPublisher(
      (next) => this.document = next,
    );
    transactions = ProjectTransactionService(
      repository: repository,
      publisher: publisher,
      now: () => fixtureTime,
    );
    controller = TaggingController(
      ProjectCommandFactory(SequenceIdGenerator(commandIds)),
    );
    providers = TaggingProviders(
      controller: controller,
      currentDocument: () => this.document,
      transactions: transactions,
      manualTransactionId: SequenceIdGenerator(transactionIds).next,
    );
  }

  ProjectDocument document;
  late final RecordingProjectRepository repository;
  late final UpdatingProjectDocumentPublisher publisher;
  late final ProjectTransactionService transactions;
  late final TaggingController controller;
  late final TaggingProviders providers;
}

Widget taggingTestApp({required Widget child, TaggingWidgetHarness? harness}) =>
    ProviderScope(
      overrides: [
        taggingProvidersProvider.overrideWithValue(harness?.providers),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

final class UpdatingProjectDocumentPublisher
    implements ProjectDocumentPublisher {
  UpdatingProjectDocumentPublisher(this._onPublish);

  final void Function(ProjectDocument document) _onPublish;
  int publishCalls = 0;

  @override
  void publish(
    ProjectDocument document, {
    List<ProjectSaveWarning> warnings = const [],
  }) {
    publishCalls++;
    _onPublish(document);
  }
}
