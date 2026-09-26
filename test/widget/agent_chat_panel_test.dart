import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/models/chat_message.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/agent_chat_panel.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';

void main() {
  testWidgets('AgentChatPanel renders suggested prompts when no messages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AgentChatPanel(),
          ),
        ),
      ),
    );

    expect(find.text('AI Assistant'), findsOneWidget);
    for (final prompt in AgentChatPanel.suggestedPrompts) {
      expect(find.text(prompt), findsOneWidget);
    }
    expect(find.text('Type a command...'), findsOneWidget);
  });

  testWidgets('AgentChatPanel has send button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AgentChatPanel(),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('AgentChatPanel shows model selector', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AgentChatPanel(),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.memory), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });

  group('structured result mapping (no Error: string-matching)', () {
    test('success maps to applied', () {
      expect(
        messageStatusForSubmit(SubmitStatus.success),
        equals(MessageStatus.applied),
      );
    });

    test('clarification maps to needsClarification', () {
      expect(
        messageStatusForSubmit(SubmitStatus.clarificationNeeded),
        equals(MessageStatus.needsClarification),
      );
    });

    test('error maps to error', () {
      expect(
        messageStatusForSubmit(SubmitStatus.error),
        equals(MessageStatus.error),
      );
    });

    test('agent message carries resulting operation IDs', () {
      final message = ChatMessage(
        id: 'm1',
        role: ChatRole.agent,
        content: 'Trimmed',
        timestamp: DateTime(2026, 1, 1),
        status: MessageStatus.applied,
        resultingOperationIds: const ['op_1'],
      );
      expect(message.resultingOperationIds, equals(['op_1']));
      expect(message.status, equals(MessageStatus.applied));
    });
  });

  group('timeline + preview refresh after successful edit', () {
    test('ProjectNotifier.applyEdit updates clip and edit history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const trackId = 'track_1';
      const clipId = 'clip_1';
      final project = Project(
        id: 'p1',
        name: 'Test',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        sourceMediaPaths: [r'C:\v\input.mp4'],
        tracks: [
          const Track(
            id: trackId,
            type: TrackType.video,
            label: 'Video',
            clips: [
              Clip(
                id: clipId,
                trackId: trackId,
                sourcePath: r'C:\v\input.mp4',
                startMs: 0,
                endMs: 60000,
              ),
            ],
          ),
        ],
        durationMs: 60000,
        outputDir: r'C:\out',
      );
      container.read(projectProvider.notifier).setProject(project);

      final op = EditOperation(
        id: 'op_1',
        type: EditOperationType.trim,
        targetClipIds: const [clipId],
        params: const {'start': '5', 'end': '15'},
        createdAt: DateTime(2026, 1, 2),
        status: OperationStatus.applied,
        ffmpegCommand: 'ffmpeg -i input',
      );
      container
          .read(projectProvider.notifier)
          .applyEdit(op, r'C:\out\op_1.mp4');

      final updated = container.read(projectProvider).valueOrNull!;
      // Timeline watches projectProvider: clip source now points at output.
      expect(updated.tracks.first.clips.first.sourcePath,
          equals(r'C:\out\op_1.mp4'));
      // Edit lands in history for undo/DB.
      expect(updated.editHistory.map((e) => e.id), contains('op_1'));
    });

    test('preview path provider points at the new output after success', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Panel sets this after SubmitResult.success; PreviewPlayer watches it.
      container.read(currentVideoPathProvider.notifier).state =
          r'C:\out\op_1.mp4';
      expect(container.read(currentVideoPathProvider),
          equals(r'C:\out\op_1.mp4'));
    });

    test('chatMessagesProvider stores resultingOperationIds', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(chatMessagesProvider.notifier).addAgentResult(
            id: 'm1',
            content: 'Trimmed',
            status: MessageStatus.applied,
            resultingOperationIds: const ['op_1'],
          );
      final messages = container.read(chatMessagesProvider);
      expect(messages, hasLength(1));
      expect(messages.first.resultingOperationIds, equals(['op_1']));
    });
  });
}
