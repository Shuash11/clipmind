import 'package:clipmind/features/tagging/presentation/widgets/marker_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns valid point and range presentation form values', (
    tester,
  ) async {
    MarkerEditorFormValue? point;
    await tester.pumpWidget(_dialogHost((value) => point = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Marker label'), '  Beat  ');
    await tester.enterText(find.bySemanticsLabel('Marker color'), '#12AB9F');
    await tester.enterText(find.bySemanticsLabel('Marker time'), '250');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Save marker'));
    await tester.pumpAndSettle();
    expect(
      point,
      const MarkerEditorFormValue(label: 'Beat', color: '#12AB9F', atMs: 250),
    );

    MarkerEditorFormValue? range;
    await tester.pumpWidget(_dialogHost((value) => range = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Range marker'));
    await tester.enterText(find.bySemanticsLabel('Marker label'), 'Intro');
    await tester.enterText(find.bySemanticsLabel('Marker color'), '#AA5511');
    await tester.enterText(find.bySemanticsLabel('Range start'), '300');
    await tester.enterText(find.bySemanticsLabel('Range end'), '700');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Save marker'));
    await tester.pumpAndSettle();
    expect(
      range,
      const MarkerEditorFormValue(
        label: 'Intro',
        color: '#AA5511',
        startMs: 300,
        endMs: 700,
      ),
    );
  });

  testWidgets('blocks malformed shapes, labels, and colors', (tester) async {
    MarkerEditorFormValue? result;
    await tester.pumpWidget(_dialogHost((value) => result = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Range marker'));
    await tester.enterText(find.bySemanticsLabel('Marker label'), 'x' * 121);
    await tester.enterText(find.bySemanticsLabel('Marker color'), '#112233');
    await tester.enterText(find.bySemanticsLabel('Range start'), '400');
    await tester.enterText(find.bySemanticsLabel('Range end'), '300');
    await tester.pump();
    expect(find.bySemanticsLabel('Save marker'), findsOneWidget);
    final submit = find.widgetWithText(FilledButton, 'Save marker');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.bySemanticsLabel('Marker label'), 'Intro');
    await tester.enterText(find.bySemanticsLabel('Marker color'), '112233');
    await tester.enterText(find.bySemanticsLabel('Range start'), '-1');
    await tester.enterText(find.bySemanticsLabel('Range end'), '100');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.bySemanticsLabel('Marker label'),
      'Intro\u0007',
    );
    await tester.enterText(find.bySemanticsLabel('Marker color'), '#112233');
    await tester.enterText(find.bySemanticsLabel('Range start'), '0');
    await tester.enterText(find.bySemanticsLabel('Range end'), '100');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(result, isNull);
  });
}

Widget _dialogHost(ValueChanged<MarkerEditorFormValue?> onResult) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async => onResult(
              await showDialog<MarkerEditorFormValue>(
                context: context,
                builder: (_) => const MarkerEditorDialog(),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
