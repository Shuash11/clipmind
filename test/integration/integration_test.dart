import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/app.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/state/settings_providers.dart';

ProviderScope _testApp() {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
    ],
    child: const ClipMindApp(),
  );
}

void main() {
  group('ClipMind Smoke Tests', () {
    testWidgets('App launches to ProjectHubScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      expect(find.text('ClipMind'), findsOneWidget);
    });

    testWidgets('Import section is visible', (WidgetTester tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      expect(find.text('Import from'), findsOneWidget);
      expect(find.text('YouTube'), findsOneWidget);
      expect(find.text('Google Drive'), findsOneWidget);
      expect(find.text('Direct URL'), findsOneWidget);
    });

    testWidgets('Recent Projects section loads', (WidgetTester tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      expect(find.text('Recent projects'), findsOneWidget);
    });

    testWidgets('Bottom URL input field renders', (WidgetTester tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      expect(find.text('Paste a video URL'), findsOneWidget);
    });

    testWidgets('App bar has ClipMind title', (WidgetTester tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      final titleFinder = find.text('ClipMind');
      expect(titleFinder, findsOneWidget);
    });
  });
}
