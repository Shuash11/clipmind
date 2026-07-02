import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:clipmind/app.dart';

void main() {
  testWidgets('ClipMind app renders project hub', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ClipMindApp()),
    );
    expect(find.text('ClipMind'), findsOneWidget);
  });
}
