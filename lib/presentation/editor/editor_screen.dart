import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'widgets/preview_player.dart';
import 'widgets/timeline/timeline_view.dart';
import 'widgets/agent_chat/agent_chat_panel.dart';
import 'widgets/toolbar/left_tool_rail.dart';
import 'widgets/toolbar/top_action_bar.dart';
import 'widgets/status_bar.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final String projectId;
  const EditorScreen({super.key, required this.projectId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  AsyncValue<Project?> _projectState = const AsyncValue.loading();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProject);
  }

  @override
  void didUpdateWidget(covariant EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      Future.microtask(_loadProject);
    }
  }

  Future<void> _loadProject() async {
    setState(() => _projectState = const AsyncValue.loading());
    try {
      final repository = ref.read(projectRepositoryProvider);
      final project = await repository.loadFromId(widget.projectId);
      if (!mounted) return;

      if (project == null) {
        ref.read(projectProvider.notifier).clearProject();
        ref.read(currentVideoPathProvider.notifier).state = null;
        setState(() => _projectState = const AsyncValue.data(null));
        return;
      }

      ref.read(projectProvider.notifier).setProject(project);
      ref
          .read(currentVideoPathProvider.notifier)
          .state = project.sourceMediaPaths.isNotEmpty
          ? project.sourceMediaPaths.first
          : null;
      setState(() => _projectState = AsyncValue.data(project));
    } catch (error, stackTrace) {
      if (mounted) {
        setState(() => _projectState = AsyncValue.error(error, stackTrace));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _projectState.when(
      loading: () => const Scaffold(
        body: _ProjectStateMessage(
          icon: Icons.hourglass_empty_rounded,
          title: 'Opening project',
          message: 'Loading timeline and media sources.',
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: _ProjectStateMessage(
          icon: Icons.error_outline_rounded,
          title: 'Could not open project',
          message: 'Return to the hub and try again.',
          actionLabel: 'Back to hub',
          onAction: () => context.go(projectHubPath),
        ),
      ),
      data: (project) {
        if (project == null) {
          return Scaffold(
            body: _ProjectStateMessage(
              icon: Icons.folder_off_outlined,
              title: 'Project not found',
              message: 'This project may have been moved or deleted.',
              actionLabel: 'Back to hub',
              onAction: () => context.go(projectHubPath),
            ),
          );
        }
        return const _EditorShell();
      },
    );
  }
}

class _EditorShell extends StatelessWidget {
  const _EditorShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClipMindColors.bgBase,
      body: Column(
        children: [
          const TopActionBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showAssistant = constraints.maxWidth >= 1060;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Row(
                    children: [
                      const LeftToolRail(),
                      const SizedBox(width: 10),
                      const Expanded(child: _WorkspaceStack()),
                      if (showAssistant) ...[
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 340,
                          child: _EditorPanel(child: AgentChatPanel()),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const StatusBar(),
        ],
      ),
    );
  }
}

class _WorkspaceStack extends StatelessWidget {
  const _WorkspaceStack();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(flex: 3, child: _EditorPanel(child: PreviewPlayer())),
        SizedBox(height: 10),
        Expanded(flex: 1, child: _EditorPanel(child: TimelineView())),
      ],
    );
  }
}

class _EditorPanel extends StatelessWidget {
  final Widget child;

  const _EditorPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ClipMindColors.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ClipMindColors.borderColor),
        ),
        child: child,
      ),
    );
  }
}

class _ProjectStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ProjectStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ClipMindColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ClipMindColors.borderColor),
              ),
              child: Icon(icon, size: 32, color: ClipMindColors.accentPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
