import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/core/router/app_router.dart';

/// Hub top bar: two-tone wordmark, "AI model" and "+ New project" pills,
/// and the retained settings action.
class HubTopBar extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onNewProject;

  const HubTopBar({
    super.key,
    required this.onSettings,
    required this.onNewProject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: ClipMindColors.bgBase,
        border: Border(bottom: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ClipMindColors.accentPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ClipMindColors.accentPrimary.withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(
              Icons.movie_filter_rounded,
              color: ClipMindColors.accentPrimary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          const _Wordmark(),
          const Spacer(),
          // Scale-down fit: the pills shrink instead of overflowing the bar
          // on narrow windows (same pattern as the editor chat panel header).
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: OutlinedButton.icon(
                onPressed: () => context.go(aiProvidersPath),
                icon: const Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: ClipMindColors.accentPrimary,
                ),
                label: const Text('AI model', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: FilledButton(
                key: const ValueKey('new-project-pill'),
                onPressed: onNewProject,
                style: FilledButton.styleFrom(
                  backgroundColor: ClipMindColors.textPrimary,
                  foregroundColor: ClipMindColors.bgBase,
                ),
                child: const Text('+ New project', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Settings',
            child: IconButton(
              key: const ValueKey('project-hub-settings'),
              icon: const Icon(Icons.settings_rounded),
              onPressed: onSettings,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-tone wordmark: "Clip" in secondary text, "Mind" bold in primary.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Clip',
            style: theme.textTheme.displaySmall?.copyWith(
              color: ClipMindColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: 'Mind',
            style: theme.textTheme.displaySmall,
          ),
        ],
      ),
    );
  }
}
