import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/data/models/project.dart';

class RecentProjectCard extends StatelessWidget {
  final Project project;

  const RecentProjectCard({super.key, required this.project});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        context.go(editorPath.replaceAll(':projectId', project.id));
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: ClipMindColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ClipMindColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: _buildThumbnail(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: theme.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(project.updatedAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (project.thumbnailPath != null &&
        project.thumbnailPath!.isNotEmpty &&
        File(project.thumbnailPath!).existsSync()) {
      return Image.file(
        File(project.thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholderThumbnail(),
      );
    }
    return _buildPlaceholderThumbnail();
  }

  Widget _buildPlaceholderThumbnail() {
    return Container(
      color: ClipMindColors.bgElevated,
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          size: 40,
          color: ClipMindColors.textMuted,
        ),
      ),
    );
  }
}
