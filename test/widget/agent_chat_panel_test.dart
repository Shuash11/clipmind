import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/agent_chat_panel.dart';

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
}
