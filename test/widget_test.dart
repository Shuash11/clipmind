import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clipmind/app.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/state/settings_providers.dart';

void main() {
  testWidgets('ClipMind app renders project hub', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
        ],
        child: const ClipMindApp(),
      ),
    );
    expect(find.text('ClipMind'), findsOneWidget);
  });
}
