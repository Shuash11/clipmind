import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/presentation/editor/widgets/agent_chat/model_selector_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('legacy selector forwards to the dynamic selector', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ClipMindTheme.dark,
          home: const Scaffold(body: ModelSelectorDropdown()),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('dynamic-model-selector')),
      findsOneWidget,
    );
    expect(find.text('Flash'), findsNothing);
  });
}
