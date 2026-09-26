import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/chat_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatStep JSON', () {
    test('round-trips a full edit step', () {
      const step = ChatStep(
        toolCallId: 'call_1',
        toolName: 'trim_clip',
        args: {'clip_id': 'clip_1', 'factor': 2.0},
        summary: 'Trimmed clip.',
        success: true,
        durationMs: 120,
        round: 1,
        kind: ChatStepKind.edit,
      );

      final revived = ChatStep.fromJson(step.toJson());

      expect(revived, equals(step));
      expect(revived.args['clip_id'], equals('clip_1'));
      expect(revived.kind, equals(ChatStepKind.edit));
    });

    test('round-trips empty args map and defaults', () {
      const step = ChatStep(
        toolCallId: 'call_2',
        toolName: 'list_project_clips',
      );

      final revived = ChatStep.fromJson(step.toJson());

      expect(revived.args, isEmpty);
      expect(revived.success, isFalse);
      expect(revived.kind, equals(ChatStepKind.read));
      expect(revived.summary, isEmpty);
    });

    test('ChatMessage defaults steps to empty and round-trips', () {
      final msg = ChatMessage(
        id: 'm1',
        role: ChatRole.agent,
        content: 'Done.',
        timestamp: DateTime(2026, 1, 1),
      );

      expect(msg.steps, isEmpty);
      expect(msg.resultingOperationIds, isEmpty);

      final revived = ChatMessage.fromJson(msg.toJson());

      expect(revived.steps, isEmpty);
      expect(revived.resultingOperationIds, isEmpty);
    });

    test('ChatMessage without steps key decodes to empty list', () {
      final revived = ChatMessage.fromJson({
        'id': 'm2',
        'role': 'user',
        'content': 'Hi',
        'timestamp': DateTime(2026, 1, 2).toIso8601String(),
      });

      expect(revived.steps, isEmpty);
    });

    test('ChatMessage round-trips steps and operation ids', () {
      final msg = ChatMessage(
        id: 'm3',
        role: ChatRole.agent,
        content: 'Applied.',
        timestamp: DateTime(2026, 1, 3),
        resultingOperationIds: const ['op_1', 'op_2'],
        steps: const [
          ChatStep(
            toolCallId: 'call_1',
            toolName: 'mute_clip',
            args: {'clip_id': 'clip_1'},
            summary: 'Muted.',
            success: true,
            durationMs: 40,
            round: 1,
            kind: ChatStepKind.edit,
          ),
        ],
      );

      final revived = ChatMessage.fromJson(msg.toJson());

      expect(revived.steps, hasLength(1));
      expect(revived.steps.single.toolName, equals('mute_clip'));
      expect(
        revived.resultingOperationIds,
        equals(['op_1', 'op_2']),
      );
    });
  });
}
