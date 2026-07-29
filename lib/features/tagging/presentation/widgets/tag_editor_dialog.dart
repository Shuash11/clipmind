import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:flutter/material.dart';

final class TagEditorFormValue {
  const TagEditorFormValue({required this.name, required this.color});

  final String name;
  final String color;

  @override
  bool operator ==(Object other) =>
      other is TagEditorFormValue && name == other.name && color == other.color;

  @override
  int get hashCode => Object.hash(name, color);
}

final class TagEditorDialog extends StatefulWidget {
  const TagEditorDialog({this.initialValue, super.key});

  final TagEditorFormValue? initialValue;

  @override
  State<TagEditorDialog> createState() => _TagEditorDialogState();
}

final class _TagEditorDialogState extends State<TagEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _color;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialValue?.name ?? '');
    _color = TextEditingController(text: widget.initialValue?.color ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    super.dispose();
  }

  bool get _isValid {
    final name = _name.text.trim();
    return name.isNotEmpty &&
        name.length <= 64 &&
        !name.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f) &&
        RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(_color.text.trim());
  }

  void _submit() {
    if (!_isValid) return;
    Navigator.of(context).pop(
      TagEditorFormValue(name: _name.text.trim(), color: _color.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialValue != null;
    final submitLabel = isEditing ? 'Save tag' : 'Create tag';
    return AlertDialog(
      backgroundColor: ClipMindColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: ClipMindColors.borderColor),
      ),
      title: Text(isEditing ? 'Edit tag' : 'New tag'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tag name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _color,
              decoration: const InputDecoration(labelText: 'Tag color'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          child: Text(submitLabel),
        ),
      ],
    );
  }
}
