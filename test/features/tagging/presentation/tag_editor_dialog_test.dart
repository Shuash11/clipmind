import 'package:clipmind/features/tagging/presentation/widgets/tag_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns trimmed valid create and edit form values', (
    tester,
  ) async {
    TagEditorFormValue? created;
    await tester.pumpWidget(_dialogHost((value) => created = value));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Tag name'), '  Travel  ');
    await tester.enterText(find.bySemanticsLabel('Tag color'), '#12AB9F');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Create tag'));
    await tester.pumpAndSettle();

    expect(created, const TagEditorFormValue(name: 'Travel', color: '#12AB9F'));

    TagEditorFormValue? edited;
    await tester.pumpWidget(
      _dialogHost(
        (value) => edited = value,
        initialValue: const TagEditorFormValue(
          name: 'Travel',
          color: '#112233',
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Tag name'), 'Work');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Save tag'));
    await tester.pumpAndSettle();
    expect(edited, const TagEditorFormValue(name: 'Work', color: '#112233'));
  });

  testWidgets('blocks empty, overlength, and malformed color submissions', (
    tester,
  ) async {
    TagEditorFormValue? result;
    await tester.pumpWidget(_dialogHost((value) => result = value));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Create tag'), findsOneWidget);
    final submit = find.widgetWithText(FilledButton, 'Create tag');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.bySemanticsLabel('Tag name'), 'x' * 65);
    await tester.enterText(find.bySemanticsLabel('Tag color'), '#123456');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.bySemanticsLabel('Tag name'), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.bySemanticsLabel('Tag name'), 'Travel\u0007');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.bySemanticsLabel('Tag name'), 'Travel');
    await tester.enterText(find.bySemanticsLabel('Tag color'), '#12345');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(result, isNull);
  });
}

Widget _dialogHost(
  ValueChanged<TagEditorFormValue?> onResult, {
  TagEditorFormValue? initialValue,
}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => FilledButton(
        onPressed: () async => onResult(
          await showDialog<TagEditorFormValue>(
            context: context,
            builder: (_) => TagEditorDialog(initialValue: initialValue),
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  ),
);
