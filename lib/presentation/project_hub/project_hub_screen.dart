import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/state/project_providers.dart';
import 'widgets/upload_dropzone.dart';
import 'widgets/import_source_card.dart';
import 'widgets/recent_project_card.dart';

class ProjectHubScreen extends ConsumerWidget {
  const ProjectHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentProjectsAsync = ref.watch(recentProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('ClipMind', style: theme.textTheme.displaySmall),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UploadDropzone(),
                  const SizedBox(height: 24),
                  Text('Import from', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: ImportSourceCard(
                        icon: Icons.play_circle_fill,
                        label: 'YouTube',
                        source: 'youtube',
                      )),
                      SizedBox(width: 12),
                      Expanded(child: ImportSourceCard(
                        icon: Icons.cloud,
                        label: 'Google Drive',
                        source: 'gdrive',
                      )),
                      SizedBox(width: 12),
                      Expanded(child: ImportSourceCard(
                        icon: Icons.link,
                        label: 'Paste a URL',
                        source: 'url',
                      )),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Projects', style: theme.textTheme.titleMedium),
                      TextButton(onPressed: () {}, child: const Text('View all')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  recentProjectsAsync.when(
                    data: (projects) {
                      if (projects.isEmpty) {
                        return _buildEmptyRecent(theme);
                      }
                      return SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: projects.length,
                          itemBuilder: (context, index) =>
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: RecentProjectCard(project: projects[index]),
                              ),
                        ),
                      );
                    },
                    loading: () => _buildLoading(theme),
                    error: (e, _) => Text('Could not load projects',
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Paste a video URL...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.upload),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return SizedBox(
      height: 160,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: ClipMindColors.accentPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyRecent(ThemeData theme) {
    return SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_creation_outlined,
                size: 32, color: ClipMindColors.textMuted),
            const SizedBox(height: 8),
            Text('No recent projects. Drop a video to start.',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
