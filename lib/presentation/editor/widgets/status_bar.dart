import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/state/agent_run_providers.dart';
import 'package:clipmind/state/status_providers.dart';

/// Real status pills over live state: provider connection, FFmpeg
/// availability and the agent run state. Three pills max; the agent pill
/// hides when idle/cancelled.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(providerHealthProvider);
    final ffmpeg = ref.watch(ffmpegBinaryAvailableProvider);
    final runState = ref.watch(agentRunControllerProvider);

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
          _providerPill(health),
          const SizedBox(width: 8),
          _ffmpegPill(ffmpeg),
          if (runState == AgentRunState.running ||
              runState == AgentRunState.planReady) ...[
            const SizedBox(width: 8),
            _agentPill(runState),
          ],
        ],
      ),
    );
  }

  /// connected -> green dot + "AI connected"; connecting/loading ->
  /// spinner/muted + "Connecting…"; disconnected/error -> red + offline.
  Widget _providerPill(AsyncValue<ConnectionStatus> health) {
    return health.when(
      data: (status) => switch (status) {
        ConnectionStatus.connected => const _StatusPill(
            key: ValueKey('status-provider-pill'),
            color: ClipMindColors.statusReady,
            label: 'AI connected',
          ),
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
  /// idle/cancelled -> hidden (the caller keeps the bar at ≤2 pills).
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

/// One compact status pill: status dot (or spinner) + label, pill radius.
class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;
  final bool spinner;

  const _StatusPill({
    super.key,
    required this.color,
    required this.label,
    this.spinner = false,
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
          if (spinner)
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
