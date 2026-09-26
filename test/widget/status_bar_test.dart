import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/presentation/editor/widgets/status_bar.dart';

void main() {
  testWidgets('StatusBar renders truthful status indicators', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StatusBar())),
    );

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('FFmpeg ready'), findsOneWidget);
    expect(find.text('Flash connected'), findsNothing);
  });

  testWidgets('StatusBar renders status pill containers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StatusBar())),
    );

    expect(find.byType(Container), findsNWidgets(5));
  });
}
