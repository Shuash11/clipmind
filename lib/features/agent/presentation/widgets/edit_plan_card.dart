import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/features/agent/domain/entities/edit_plan.dart';
import 'package:clipmind/features/agent/presentation/providers/edit_plan_state.dart';
import 'package:clipmind/features/projects/domain/transactions/project_save_outcome.dart';
import 'package:flutter/material.dart';

import 'edit_plan_operation_row.dart';

/// A local change ledger. It renders only canonical, already validated plan data.
final class EditPlanCard extends StatelessWidget {
  const EditPlanCard({
    super.key,
    required this.plan,
    this.action = EditPlanAction.idle,
    this.failureMessage,
    this.saveOutcome,
    this.onApply,
    this.onCancel,
    this.onRevise,
  });

  final EditPlan plan;
  final EditPlanAction action;
  final String? failureMessage;
  final ProjectSaveOutcome? saveOutcome;
  final VoidCallback? onApply;
  final VoidCallback? onCancel;
  final VoidCallback? onRevise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = action != EditPlanAction.idle;
    final canApply =
        !isBusy &&
        (plan.status == EditPlanStatus.valid ||
            plan.status == EditPlanStatus.approved);
    final canCancel =
        !isBusy &&
        (plan.status == EditPlanStatus.draft ||
            plan.status == EditPlanStatus.valid ||
            plan.status == EditPlanStatus.approved);
    final canRevise =
        !isBusy &&
        (plan.status == EditPlanStatus.draft ||
            plan.status == EditPlanStatus.rejected ||
            plan.status == EditPlanStatus.valid ||
            plan.status == EditPlanStatus.approved);
    final warning = saveOutcome?.warnings.isNotEmpty == true;
    final statusColor = _statusColor(plan.status, warning);

    return Semantics(
      container: true,
      label: 'Edit plan preview',
      child: Container(
        key: const ValueKey('edit-plan-card'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ClipMindColors.surfaceCard,
          border: Border.all(color: statusColor.withValues(alpha: .7)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 28, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: 'Plan status ${_statusLabel(plan.status, action)}',
                    child: Text(
                      _statusLabel(plan.status, action),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: statusColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                Text(
                  'r${plan.baseRevision} · ${_opaque(plan.baseProjectId)}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_safeText(plan.summary), style: theme.textTheme.bodyMedium),
            if (plan.payload != null) ...[
              const SizedBox(height: 10),
              Text(
                'COMMAND LEDGER · ${plan.payload!.summaries.length}',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              ...plan.payload!.summaries.map(
                (summary) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: EditPlanOperationRow(summary: summary),
                ),
              ),
            ],
            if (failureMessage != null || plan.findings.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Notice(
                color: ClipMindColors.statusError,
                message: _safeText(
                  failureMessage ?? plan.findings.first.message,
                ),
              ),
            ],
            if (plan.status == EditPlanStatus.failed ||
                plan.status == EditPlanStatus.cancelled ||
                plan.status == EditPlanStatus.revised) ...[
              const SizedBox(height: 8),
              Text(
                plan.status == EditPlanStatus.failed
                    ? 'No changes were applied.'
                    : 'This preview was not applied.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (warning) ...[
              const SizedBox(height: 10),
              _Notice(
                color: ClipMindColors.statusWarning,
                message:
                    'Applied with ${saveOutcome!.warnings.length} durable save warning${saveOutcome!.warnings.length == 1 ? '' : 's'}.',
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tooltip(
                  message: 'Persist this validated preview',
                  child: Semantics(
                    button: true,
                    enabled: canApply,
                    label: 'Apply edit plan',
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        key: const ValueKey('edit-plan-apply'),
                        onPressed: canApply ? onApply : null,
                        child: const Text('Apply'),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Discard this preview',
                  child: Semantics(
                    button: true,
                    enabled: canCancel,
                    label: 'Cancel edit plan',
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        key: const ValueKey('edit-plan-cancel'),
                        onPressed: canCancel ? onCancel : null,
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Request a revised preview',
                  child: Semantics(
                    button: true,
                    enabled: canRevise,
                    label: 'Revise edit plan',
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        key: const ValueKey('edit-plan-revise'),
                        onPressed: canRevise ? onRevise : null,
                        child: const Text('Revise'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(EditPlanStatus status, EditPlanAction action) {
    if (action == EditPlanAction.planning) return 'PLANNING';
    if (action == EditPlanAction.applying) return 'APPLYING';
    if (action == EditPlanAction.revising) return 'REVISING';
    return switch (status) {
      EditPlanStatus.valid || EditPlanStatus.approved => 'PREVIEW',
      EditPlanStatus.draft => 'DRAFT',
      EditPlanStatus.rejected => 'REJECTED',
      EditPlanStatus.applied => 'APPLIED',
      EditPlanStatus.cancelled => 'CANCELLED',
      EditPlanStatus.revised => 'REVISED',
      EditPlanStatus.failed => 'FAILED',
    };
  }

  static Color _statusColor(EditPlanStatus status, bool warning) {
    if (warning) return ClipMindColors.statusWarning;
    return switch (status) {
      EditPlanStatus.valid ||
      EditPlanStatus.approved => ClipMindColors.accentPrimary,
      EditPlanStatus.applied => ClipMindColors.statusReady,
      EditPlanStatus.failed ||
      EditPlanStatus.rejected => ClipMindColors.statusError,
      EditPlanStatus.cancelled ||
      EditPlanStatus.revised => ClipMindColors.textMuted,
      EditPlanStatus.draft => ClipMindColors.statusWarning,
    };
  }

  static String _safeText(String value) =>
      _isPathLike(value) ||
          value.codeUnits.any((unit) => unit < 32 || unit == 127)
      ? 'Proposed editor changes.'
      : value;
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

final class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.message});
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
    child: Text(message, style: Theme.of(context).textTheme.bodySmall),
  );
}
