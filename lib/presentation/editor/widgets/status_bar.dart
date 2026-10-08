import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/status_providers.dart';

/// Real status pills over live state: provider connection, FFmpeg
/// availability, project-save failures and the agent run state. Four pills
/// max; the agent pill hides when idle/cancelled and the save-failure pill
/// hides while persistence is known-healthy.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(providerHealthProvider);
    final ffmpeg = ref.watch(ffmpegBinaryAvailableProvider);
    final saveFailure = ref.watch(projectSaveFailureProvider);
    final runState = ref.watch(agentRunControllerProvider);
    final modelName = ref.watch(resolvedModelNameProvider).value;

    return Container(
      key: const ValueKey('status-bar'),
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: ClipMindColors.bgBase,
        border: Border(top: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Row(
        children: [
          _providerPill(health, modelName),
          const SizedBox(width: 8),
          _ffmpegPill(ffmpeg),
          if (runState == AgentRunState.running ||
              runState == AgentRunState.planReady) ...[
            const SizedBox(width: 8),
            _agentPill(runState),
          ],
          if (saveFailure != null) ...[
            const SizedBox(width: 8),
            _SaveFailurePill(
              key: const ValueKey('status-save-failure-pill'),
              failure: saveFailure,
            ),
          ],
        ],
      ),
    );
  }

  /// connected -> green dot + "AI connected · {model}" (ids truncated to
  /// ~24 chars + a tooltip with the full name) or plain "AI connected";
  /// connecting/loading -> spinner/muted + "Connecting…"; disconnected/
  /// error -> red + offline.
  Widget _providerPill(
    AsyncValue<ConnectionStatus> health,
    String? modelName,
  ) {
    return health.when(
      data: (status) => switch (status) {
        ConnectionStatus.connected => _connectedPill(modelName),
        ConnectionStatus.connecting => const _StatusPill(
            key: ValueKey('status-provider-pill'),
            color: ClipMindColors.textMuted,
            label: 'Connecting…',
            spinner: true,
          ),
        ConnectionStatus.disconnected ||
        ConnectionStatus.error =>
          const _StatusPill(
            key: ValueKey('status-provider-pill'),
            color: ClipMindColors.statusError,
            label: 'Provider offline',
          ),
      },
      loading: () => const _StatusPill(
        key: ValueKey('status-provider-pill'),
        color: ClipMindColors.textMuted,
        label: 'Connecting…',
      ),
      error: (_, _) => const _StatusPill(
        key: ValueKey('status-provider-pill'),
        color: ClipMindColors.statusError,
        label: 'Provider offline',
      ),
    );
  }

  /// "AI connected" when no OpenAI-compatible model resolves; with one,
  /// "AI connected · {model}" (truncated) + a tooltip with the full name.
  Widget _connectedPill(String? modelName) {
    final pill = _StatusPill(
      key: const ValueKey('status-provider-pill'),
      color: ClipMindColors.statusReady,
      label: modelName == null || modelName.isEmpty
          ? 'AI connected'
          : 'AI connected · ${_truncateModel(modelName)}',
    );
    if (modelName == null || modelName.isEmpty) return pill;
    return Tooltip(message: 'AI connected · $modelName', child: pill);
  }

  /// Model ids like `meta/llama-3.3-70b-instruct` are long — protect the
  /// 32px bar by truncating to 24 chars + an ellipsis.
  String _truncateModel(String model) {
    if (model.length <= 24) return model;
    return '${model.substring(0, 24)}…';
  }

  /// true -> green "FFmpeg ready"; false/error -> red "FFmpeg missing".
  Widget _ffmpegPill(AsyncValue<bool> ffmpeg) {
    return ffmpeg.when(
      data: (available) => available
          ? const _StatusPill(
              key: ValueKey('status-ffmpeg-pill'),
              color: ClipMindColors.statusReady,
              label: 'FFmpeg ready',
            )
          : const _StatusPill(
              key: ValueKey('status-ffmpeg-pill'),
              color: ClipMindColors.statusError,
              label: 'FFmpeg missing',
            ),
      loading: () => const _StatusPill(
        key: ValueKey('status-ffmpeg-pill'),
        color: ClipMindColors.textMuted,
        label: 'FFmpeg…',
      ),
      error: (_, _) => const _StatusPill(
        key: ValueKey('status-ffmpeg-pill'),
        color: ClipMindColors.statusError,
        label: 'FFmpeg missing',
      ),
    );
  }

  /// running -> spinner "AI working…"; planReady -> "Plan ready";
  /// idle/cancelled -> hidden (the bar's other pills stay at ≤3).
  Widget _agentPill(AgentRunState runState) {
    if (runState == AgentRunState.running) {
      return const _StatusPill(
        key: ValueKey('status-agent-pill'),
        color: ClipMindColors.accentPrimary,
        label: 'AI working…',
        spinner: true,
      );
    }
    return const _StatusPill(
      key: ValueKey('status-agent-pill'),
      color: ClipMindColors.accentPrimary,
      label: 'Plan ready',
    );
  }
}

/// Clickable save-failure pill: red warning icon + "Changes not saved",
/// a tooltip carrying the recorded reason, and tap-to-retry through
/// [persistProjectProvider] (the bridge is read because this holds a
/// Riverpod 3 [WidgetRef]). The 24×24 minimum target size keeps the
/// interactive pill within WCAG 2.2 SC 2.5.8 (Target Size, Minimum); the
/// icon + color + label follow the Carbon 3-of-4 status-indicator rule.
class _SaveFailurePill extends ConsumerWidget {
  const _SaveFailurePill({super.key, required this.failure});

  final ProjectSaveFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message:
          '${failure.message}\nTap to retry — it is also retried with your next edit.',
      child: Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _retry(ref),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              child: const _StatusPill(
                color: ClipMindColors.statusError,
                label: 'Changes not saved',
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Re-saves the open project. [persistProject] clears
  /// [projectSaveFailureProvider] on success (pill disappears) and refreshes
  /// it on failure (pill stays, with the new reason).
  Future<void> _retry(WidgetRef ref) async {
    final project = ref.read(projectProvider).value;
    if (project == null) return;
    await ref.read(persistProjectProvider)(project);
  }
}

/// One compact status pill: status dot (or spinner, or icon) + label, pill
/// radius.
class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;
  final bool spinner;
  final IconData? icon;

  const _StatusPill({
    super.key,
    required this.color,
    required this.label,
    this.spinner = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ClipMindColors.bgElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ClipMindColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: color)
          else if (spinner)
            const SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
