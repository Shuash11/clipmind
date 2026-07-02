import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/app.dart';

void main() {
  group('ClipMind Smoke Tests', () {
    testWidgets('App launches to ProjectHubScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: ClipMindApp()),
      );
      await tester.pump();

      expect(find.text('ClipMind'), findsOneWidget);
    });

    testWidgets('Import section is visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: ClipMindApp()),
      );
      await tester.pump();

      expect(find.text('Import from'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('Google Drive'), findsOneWidget);
      expect(find.text('Paste a URL'), findsOneWidget);
    });

    testWidgets('Recent Projects section loads', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: ClipMindApp()),
      );
      await tester.pump();

      expect(find.text('Recent Projects'), findsOneWidget);
    });

    testWidgets('Bottom URL input field renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: ClipMindApp()),
      );
      await tester.pump();

      expect(find.text('Paste a video URL...'), findsOneWidget);
    });

    testWidgets('App bar has ClipMind title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: ClipMindApp()),
      );
      await tester.pump();

      final titleFinder = find.text('ClipMind');
      expect(titleFinder, findsOneWidget);
    });
  });
}
