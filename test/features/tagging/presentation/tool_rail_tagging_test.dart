import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/tagging/presentation/widgets/media_panel.dart';
import 'package:clipmind/presentation/editor/widgets/toolbar/left_tool_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Media rail tool exposes truthful unavailable tagging media panel',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ClipMindTheme.dark,
            home: const Scaffold(body: LeftToolRail()),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Media'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaPanel), findsOneWidget);
      expect(find.text('No project available'), findsOneWidget);
      expect(find.byType(LeftToolRail), findsOneWidget);
    },
  );
}
