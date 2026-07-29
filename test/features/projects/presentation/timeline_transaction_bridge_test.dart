import 'package:clipmind/features/projects/domain/commands/clip_commands.dart';
import 'package:clipmind/features/projects/domain/commands/project_command_factory.dart';
import 'package:clipmind/features/projects/presentation/timeline_project_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/project_fakes.dart';
import '../support/project_test_data.dart';

void main() {
  test(
    'manual timeline range removal goes through factory and transaction service',
    () async {
      final gateway = RecordingProjectTransactionGateway();
      final controller = TimelineProjectController(
        factory: ProjectCommandFactory(SequenceIdGenerator(['right-clip'])),
        transactions: gateway,
        document: documentWithOneClip(),
      );
      await controller.removeRange(clipId: 'clip-1', startMs: 200, endMs: 400);
      expect(gateway.transactions, hasLength(1));
      final command = gateway.transactions.single.commands.single;
      expect(command, isA<RemoveClipRangeCommand>());
      expect((command as RemoveClipRangeCommand).rightClipId, 'right-clip');
      expect(gateway.directRepositorySaves, 0);
    },
  );
}
