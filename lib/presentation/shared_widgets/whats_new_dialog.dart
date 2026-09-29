import 'package:flutter/material.dart';

/// "What's new" dialog: the release-notes bullets for the current version.
///
/// Consistent with the existing update dialog (AlertDialog + FilledButton)
/// and the dark theme (dialogTheme: surfaceCard, radius 16).
class WhatsNewDialog extends StatelessWidget {
  final String version;
  final List<String> notes;

  const WhatsNewDialog({
    super.key,
    required this.version,
    required this.notes,
  });

  static Future<void> show(
    BuildContext context, {
    required String version,
    required List<String> notes,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => WhatsNewDialog(version: version, notes: notes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text("What's new in v$version"),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line, style: theme.textTheme.bodyMedium),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
