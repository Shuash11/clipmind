import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:flutter/material.dart';

final class MarkerEditorFormValue {
  const MarkerEditorFormValue({
    required this.label,
    required this.color,
    this.atMs,
    this.startMs,
    this.endMs,
  });

  final String label;
  final String color;
  final int? atMs;
  final int? startMs;
  final int? endMs;

  @override
  bool operator ==(Object other) =>
      other is MarkerEditorFormValue &&
      label == other.label &&
      color == other.color &&
      atMs == other.atMs &&
      startMs == other.startMs &&
      endMs == other.endMs;

  @override
  int get hashCode => Object.hash(label, color, atMs, startMs, endMs);
}

final class MarkerEditorDialog extends StatefulWidget {
  const MarkerEditorDialog({this.initialValue, super.key});

  final MarkerEditorFormValue? initialValue;

  @override
  State<MarkerEditorDialog> createState() => _MarkerEditorDialogState();
}

final class _MarkerEditorDialogState extends State<MarkerEditorDialog> {
  late final TextEditingController _label;
  late final TextEditingController _color;
  late final TextEditingController _atMs;
  late final TextEditingController _startMs;
  late final TextEditingController _endMs;
  late bool _isRange;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _isRange =
        initial?.atMs == null &&
        initial?.startMs != null &&
        initial?.endMs != null;
    _label = TextEditingController(text: initial?.label ?? '');
    _color = TextEditingController(text: initial?.color ?? '');
    _atMs = TextEditingController(text: initial?.atMs?.toString() ?? '');
    _startMs = TextEditingController(text: initial?.startMs?.toString() ?? '');
    _endMs = TextEditingController(text: initial?.endMs?.toString() ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _color.dispose();
    _atMs.dispose();
    _startMs.dispose();
    _endMs.dispose();
    super.dispose();
  }

  bool get _hasValidLabel {
    final value = _label.text.trim();
    return value.isNotEmpty &&
        value.length <= 120 &&
        !value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f);
  }

  bool get _hasValidColor =>
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(_color.text.trim());

  int? _int(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  bool get _hasValidShape {
    final atMs = _int(_atMs);
    final startMs = _int(_startMs);
    final endMs = _int(_endMs);
    if (!_isRange) {
      return atMs != null && atMs >= 0 && startMs == null && endMs == null;
    }
    return atMs == null &&
        startMs != null &&
        endMs != null &&
        startMs >= 0 &&
        endMs > startMs;
  }

  bool get _isValid => _hasValidLabel && _hasValidColor && _hasValidShape;

  void _submit() {
    if (!_isValid) return;
    Navigator.of(context).pop(
      MarkerEditorFormValue(
        label: _label.text.trim(),
        color: _color.text.trim(),
        atMs: _isRange ? null : _int(_atMs),
        startMs: _isRange ? _int(_startMs) : null,
        endMs: _isRange ? _int(_endMs) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: ClipMindColors.bgSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: ClipMindColors.borderColor),
    ),
    title: Text(widget.initialValue == null ? 'New marker' : 'Edit marker'),
    content: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Marker label',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _color,
            decoration: const InputDecoration(
              labelText: 'Marker color',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Range marker',
            toggled: _isRange,
            child: ExcludeSemantics(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Range marker'),
                value: _isRange,
                onChanged: (value) => setState(() => _isRange = value),
              ),
            ),
          ),
          TextField(
            controller: _atMs,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Marker time',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _startMs,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Range start',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _endMs,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Range end',
              isDense: true,
            ),
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
        child: const Text('Save marker'),
      ),
    ],
  );
}
