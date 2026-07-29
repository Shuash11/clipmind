import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class RevisePlanDialog extends StatefulWidget {
  const RevisePlanDialog({super.key, required this.onRevise});
  final ValueChanged<String> onRevise;

  @override
  State<RevisePlanDialog> createState() => _RevisePlanDialogState();
}

final class _RevisePlanDialogState extends State<RevisePlanDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final instruction = _controller.text.trim();
    if (instruction.isEmpty ||
        instruction.length > 1000 ||
        instruction.codeUnits.any((unit) => unit < 32 || unit == 127)) {
      setState(() => _error = 'Enter a short, safe revision instruction.');
      return;
    }
    widget.onRevise(instruction);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('revise-plan-dialog'),
    title: const Text('Revise preview'),
    content: TextField(
      key: const ValueKey('revise-plan-instruction'),
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      maxLength: 1000,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: 'Describe what should change in the next preview',
        errorText: _error,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('revise-plan-submit'),
        style: FilledButton.styleFrom(
          backgroundColor: ClipMindColors.accentPrimary,
        ),
        onPressed: _submit,
        child: const Text('Revise'),
      ),
    ],
  );
}
