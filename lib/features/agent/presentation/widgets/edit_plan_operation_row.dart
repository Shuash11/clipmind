import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/projects/domain/commands/project_command.dart';
import 'package:flutter/material.dart';

/// A safe, canonical operation entry in an edit plan command ledger.
final class EditPlanOperationRow extends StatelessWidget {
  const EditPlanOperationRow({super.key, required this.summary});

  final CanonicalCommandSummary summary;

  @override
  Widget build(BuildContext context) {
    final type = _humanize(summary.type);
    final targetCount = summary.targetIds.length;
    final targets = _targets(summary.targetIds);
    return Semantics(
      label: '$type, $targetCount target${targetCount == 1 ? '' : 's'}$targets',
      child: Text(
        '$type · $targetCount target${targetCount == 1 ? '' : 's'}$targets',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: ClipMindColors.textSecondary),
      ),
    );
  }

  static String _humanize(String value) => value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static String _targets(List<String> ids) => ids.isEmpty
      ? ''
      : ' · ${ids.take(3).map(_opaque).join(', ')}${ids.length > 3 ? '…' : ''}';

  static String _opaque(String value) => _isPathLike(value)
      ? 'restricted'
      : value.length <= 10
      ? value
      : '${value.substring(0, 6)}…${value.substring(value.length - 3)}';

  static bool _isPathLike(String value) =>
      value.contains('/') ||
      value.contains('\\') ||
      RegExp(r'^[a-zA-Z]:').hasMatch(value);
}
