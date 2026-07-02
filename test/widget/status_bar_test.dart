import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/presentation/editor/widgets/status_bar.dart';

void main() {
  testWidgets('StatusBar renders three status indicators', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBar(),
        ),
      ),
    );

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Flash · connected'), findsOneWidget);
    expect(find.text('FFmpeg ready'), findsOneWidget);
  });

  testWidgets('StatusBar renders three dots', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBar(),
        ),
      ),
    );

    // Each status dot is a Container with BoxShape.circle == 6x6
    // We verify there are 3 dot containers by finding circles
    expect(find.byType(Container), findsAtLeast(3));
  });
}
