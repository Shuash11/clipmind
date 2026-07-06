import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/data/models/project.dart';

class RecentProjectCard extends StatefulWidget {
  final Project project;

  const RecentProjectCard({super.key, required this.project});

  @override
  State<RecentProjectCard> createState() => _RecentProjectCardState();
}

class _RecentProjectCardState extends State<RecentProjectCard> {
  bool _isHovering = false;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDuration(int durationMs) {
    if (durationMs <= 0) return 'Duration pending';
    final duration = Duration(milliseconds: durationMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  bool _isImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = widget.project;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.015 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                context.go(editorPath.replaceAll(':projectId', project.id)),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 224,
              decoration: BoxDecoration(
                color: _isHovering
                    ? ClipMindColors.surfaceHover
                    : ClipMindColors.surfaceCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isHovering
                      ? ClipMindColors.accentPrimary.withValues(alpha: 0.6)
                      : ClipMindColors.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildThumbnail(project),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: AnimatedOpacity(
                              opacity: _isHovering ? 1 : 0,
                              duration: const Duration(milliseconds: 140),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: ClipMindColors.bgBase.withValues(
                                    alpha: 0.72,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: ClipMindColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: ClipMindColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatDate(project.updatedAt),
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.timelapse_rounded,
                              size: 13,
                              color: ClipMindColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _formatDuration(project.durationMs),
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(Project project) {
    final path = project.thumbnailPath;
    if (path != null && path.isNotEmpty && _isImagePath(path)) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholderThumbnail(),
        );
      }
    }
    return _buildPlaceholderThumbnail();
  }

  Widget _buildPlaceholderThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ClipMindColors.bgElevated, ClipMindColors.bgSurface],
        ),
      ),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: ClipMindColors.accentPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ClipMindColors.accentPrimary.withValues(alpha: 0.22),
            ),
          ),
          child: const Icon(
            Icons.movie_outlined,
            size: 28,
            color: ClipMindColors.accentPrimary,
          ),
        ),
      ),
    );
  }
}
