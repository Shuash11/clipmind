import 'package:clipmind/features/projects/domain/commands/clip_commands.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:clipmind/features/projects/domain/entities/project_state_snapshot.dart';
import 'package:clipmind/features/projects/domain/entities/persisted_transaction_record.dart';
import 'package:clipmind/features/projects/domain/transactions/edit_transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_test_data.dart';

void main() {
  test(
    'snapshot, document, summaries, and transaction defensively copy caller collections',
    () {
      final assets = [...stateWithOneClip().assets];
      final tracks = [...stateWithOneClip().tracks];
      final snapshot = ProjectStateSnapshot(
        assets: assets,
        tracks: tracks,
        tags: const [],
        markers: const [],
        overlays: const [],
      );
      final history = <PersistedTransactionRecord>[
        recordFor(before: snapshot, after: snapshot),
      ];
      final document = documentWithOneClip(history: history);
      final summaries = [
        CanonicalCommandSummary(type: 'set_clip_muted', targetIds: ['clip-1']),
      ];
      final commands = <ProjectCommand>[
        const SetClipMutedCommand(clipId: 'clip-1', muted: true),
      ];
      final transaction = EditTransaction(
        planId: 'plan-1',
        expectedRevision: 0,
        beforeState: snapshot,
        candidateState: snapshot,
        commands: commands,
        summaries: summaries,
        sourceKind: TransactionSourceKind.manual,
      );
      assets.clear();
      tracks.clear();
      summaries.clear();
      commands.clear();
      history.clear();
      expect(snapshot.assets, hasLength(1));
      expect(snapshot.tracks, hasLength(1));
      expect(transaction.commands, hasLength(1));
      expect(transaction.summaries, hasLength(1));
      expect(document.history, hasLength(1));
      expect(
        () => transaction.commands.add(
          const SetClipMutedCommand(clipId: 'clip-1', muted: false),
        ),
        throwsUnsupportedError,
      );
    },
  );
}
