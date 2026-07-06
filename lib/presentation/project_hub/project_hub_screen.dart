import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/update_providers.dart';
import 'package:clipmind/presentation/settings/widgets/update_dialog.dart';

import 'package:clipmind/data/services/import/youtube_import_service.dart';
import 'package:clipmind/data/services/import/gdrive_import_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'widgets/upload_dropzone.dart';
import 'widgets/import_source_card.dart';
import 'widgets/recent_project_card.dart';

class ProjectHubScreen extends ConsumerStatefulWidget {
  const ProjectHubScreen({super.key});

  @override
  ConsumerState<ProjectHubScreen> createState() => _ProjectHubScreenState();
}

class _ProjectHubScreenState extends ConsumerState<ProjectHubScreen> {
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
  bool _isDragActive = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_handleUrlChanged);
    _initUpdateCheck();
  }

  @override
  void dispose() {
    _urlController.removeListener(_handleUrlChanged);
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _handleUrlChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initUpdateCheck() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      ref
          .read(updateNotifierProvider.notifier)
          .checkForUpdate(
            currentVersion: '${info.version}+${info.buildNumber}',
          );
    } catch (_) {
      // Update checks should never block the hub from loading.
    }
  }

  Future<void> _handleBrowse() async {
    if (_isImporting) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      await _handleImportedFiles(result.files);
    }
  }

  Future<void> _handleImportedFiles(List<PlatformFile> files) async {
    for (final file in files) {
      final path = file.path;
      if (path == null || path.isEmpty) continue;
      await _openProjectForMedia(name: file.name, path: path);
      return;
    }
    _showImportError('Could not read the selected file path.');
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDragActive = false);
    if (_isImporting || details.files.isEmpty) return;

    final file = details.files.first;
    await _openProjectForMedia(name: file.name, path: file.path);
  }

  Future<void> _openProjectForMedia({
    required String name,
    required String path,
    bool manageBusy = true,
  }) async {
    if (manageBusy) {
      if (_isImporting) return;
      setState(() => _isImporting = true);
    }

    try {
      final details = await _readMediaDetails(path);
      final repository = ref.read(projectRepositoryProvider);
      final project = await repository.createNew(
        name.isEmpty ? _fileNameFromPath(path) : name,
        sourceMediaPaths: [path],
        durationMs: details.durationMs,
        thumbnailPath: details.thumbnailPath,
      );

      if (!mounted) return;
      ref.read(projectProvider.notifier).setProject(project);
      ref.read(currentVideoPathProvider.notifier).state = path;
      context.go(editorPath.replaceAll(':projectId', project.id));
    } catch (_) {
      if (mounted) {
        _showImportError('Could not create a project for that media.');
      }
    } finally {
      if (mounted && manageBusy) setState(() => _isImporting = false);
    }
  }

  Future<_MediaDetails> _readMediaDetails(String path) async {
    try {
      final ffprobe = ref.read(ffprobeServiceProvider);
      final metadata = await ffprobe.extractMetadata(path);
      final thumbnailPath = await ffprobe.generateThumbnail(path, atMs: 1000);
      return _MediaDetails(
        durationMs: metadata?.durationMs ?? 0,
        thumbnailPath: thumbnailPath,
      );
    } catch (_) {
      return const _MediaDetails();
    }
  }

  Future<void> _handleUploadUrl() async {
    final url = _urlController.text.trim();
    if (_isImporting) return;
    if (url.isEmpty) {
      _urlFocusNode.requestFocus();
      return;
    }

    setState(() => _isImporting = true);

    try {
      final dir = await _getImportDir();
      String? downloadedPath;

      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        final service = YouTubeImportService();
        downloadedPath = await service.import(url, dir.path);
      } else if (url.contains('drive.google.com')) {
        final service = GDriveImportService();
        downloadedPath = await service.import(
          url,
          '${dir.path}/gdrive_download.mp4',
        );
      } else {
        final service = GDriveImportService();
        downloadedPath = await service.import(
          url,
          '${dir.path}/direct_download.mp4',
        );
      }

      if (downloadedPath != null && mounted) {
        await _openProjectForMedia(
          name: _fileNameFromPath(downloadedPath),
          path: downloadedPath,
          manageBusy: false,
        );
      } else if (mounted) {
        _showImportError('Import failed. Check the URL and try again.');
      }
    } catch (_) {
      if (mounted) {
        _showImportError('Import failed. Check the URL and try again.');
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<Directory> _getImportDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/imports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last.trim();
    return name.isEmpty ? 'Untitled video' : name;
  }

  void _showImportError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showImportUrlDialog(String sourceType) async {
    final dialogController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canSubmit = dialogController.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text('Import from $sourceType'),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: dialogController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Paste $sourceType URL',
                  prefixIcon: const Icon(Icons.link_rounded),
                ),
                onChanged: (_) => setDialogState(() {}),
                onSubmitted: canSubmit
                    ? (value) => Navigator.pop(ctx, value.trim())
                    : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: canSubmit
                    ? () => Navigator.pop(ctx, dialogController.text.trim())
                    : null,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Import'),
              ),
            ],
          );
        },
      ),
    );
    dialogController.dispose();
    if (url != null && url.isNotEmpty) {
      _urlController.text = url;
      await _handleUploadUrl();
    }
  }

  void _showAllProjects() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final projectsAsync = ref.watch(recentProjectsProvider);
            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ClipMindColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ClipMindColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'All projects',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  projectsAsync.when(
                    data: (projects) {
                      if (projects.isEmpty) {
                        return const _CompactMessage(
                          icon: Icons.movie_creation_outlined,
                          title: 'No projects yet',
                          message:
                              'Import a video to create your first project.',
                        );
                      }
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.58,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: projects.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final project = projects[index];
                            return ListTile(
                              leading: const Icon(Icons.movie_outlined),
                              title: Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                project.updatedAt.toString().split('.').first,
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                context.go(
                                  editorPath.replaceAll(
                                    ':projectId',
                                    project.id,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const _RecentSkeleton(compact: true),
                    error: (e, _) => const _CompactMessage(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load projects',
                      message: 'Close this panel and try again.',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateState>(updateNotifierProvider, (previous, next) {
      if (next.status == UpdateStatus.available && next.release != null) {
        final r = next.release!;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!context.mounted) return;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => UpdateDialog(release: r),
          );
        });
      }
    });

    final theme = Theme.of(context);
    final recentProjectsAsync = ref.watch(recentProjectsProvider);
    final hasUrl = _urlController.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _HubTopBar(onSettings: () => context.go(settingsPath)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HubIntro(theme: theme),
                        const SizedBox(height: 18),
                        UploadDropzone(
                          onBrowse: _handleBrowse,
                          onDragEntered: (_) =>
                              setState(() => _isDragActive = true),
                          onDragExited: (_) =>
                              setState(() => _isDragActive = false),
                          onDragDone: _handleDrop,
                          isDragActive: _isDragActive,
                          isBusy: _isImporting,
                        ),
                        const SizedBox(height: 26),
                        const _SectionHeader(
                          title: 'Import from',
                          actionLabel: null,
                          onAction: null,
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildImportSources(constraints),
                        ),
                        const SizedBox(height: 34),
                        _SectionHeader(
                          title: 'Recent projects',
                          actionLabel: 'View all',
                          onAction: _showAllProjects,
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: recentProjectsAsync.when(
                            data: (projects) {
                              if (projects.isEmpty) {
                                return _buildEmptyRecent(theme);
                              }
                              return _buildRecentProjects(projects);
                            },
                            loading: () => const _RecentSkeleton(),
                            error: (e, _) => _buildRecentError(theme),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _UrlImportBar(
              controller: _urlController,
              focusNode: _urlFocusNode,
              isImporting: _isImporting,
              hasUrl: hasUrl,
              onClear: () => _urlController.clear(),
              onImport: _handleUploadUrl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSources(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth;
    final isNarrow = maxWidth < 760;
    final cardWidth = isNarrow ? maxWidth : (maxWidth - 24) / 3;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: cardWidth,
          child: ImportSourceCard(
            icon: Icons.play_circle_fill_rounded,
            label: 'YouTube',
            source: 'youtube',
            subtitle: 'Paste a video link',
            onTap: () => _showImportUrlDialog('YouTube'),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: ImportSourceCard(
            icon: Icons.cloud_rounded,
            label: 'Google Drive',
            source: 'gdrive',
            subtitle: 'Import a Drive video',
            onTap: () => _showImportUrlDialog('Google Drive'),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: ImportSourceCard(
            icon: Icons.link_rounded,
            label: 'Direct URL',
            source: 'url',
            subtitle: 'Download from a link',
            onTap: () {
              _urlController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _urlController.text.length,
              );
              _urlFocusNode.requestFocus();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentProjects(List<dynamic> projects) {
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: projects.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            RecentProjectCard(project: projects[index]),
      ),
    );
  }

  Widget _buildRecentError(ThemeData theme) {
    return _CompactMessage(
      icon: Icons.error_outline_rounded,
      title: 'Could not load projects',
      message: 'Refresh the list and try again.',
      action: TextButton.icon(
        onPressed: () => ref.invalidate(recentProjectsProvider),
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Refresh'),
      ),
    );
  }

  Widget _buildEmptyRecent(ThemeData theme) {
    return const _CompactMessage(
      icon: Icons.movie_creation_outlined,
      title: 'No recent projects yet',
      message: 'Import a video to start editing.',
    );
  }
}

class _HubTopBar extends StatelessWidget {
  final VoidCallback onSettings;

  const _HubTopBar({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              borderRadius: BorderRadius.circular(8),
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
          Text('ClipMind', style: theme.textTheme.displaySmall),
          const Spacer(),
          Tooltip(
            message: 'Settings',
            child: IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: onSettings,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubIntro extends StatelessWidget {
  final ThemeData theme;

  const _HubIntro({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a video project',
                style: theme.textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Import local media, a YouTube link, Google Drive media, or a direct video URL.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ClipMindColors.bgElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ClipMindColors.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.offline_bolt_outlined,
                size: 14,
                color: ClipMindColors.accentPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Desktop editor',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ClipMindColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _UrlImportBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isImporting;
  final bool hasUrl;
  final VoidCallback onClear;
  final VoidCallback onImport;

  const _UrlImportBar({
    required this.controller,
    required this.focusNode,
    required this.isImporting,
    required this.hasUrl,
    required this.onClear,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: const BoxDecoration(
        color: ClipMindColors.bgSurface,
        border: Border(top: BorderSide(color: ClipMindColors.borderColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !isImporting,
                  decoration: InputDecoration(
                    hintText: 'Paste a video URL',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: hasUrl
                        ? IconButton(
                            tooltip: 'Clear URL',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: isImporting ? null : onClear,
                          )
                        : null,
                  ),
                  onSubmitted: (_) => onImport(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: isImporting ? null : onImport,
                  icon: isImporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(isImporting ? 'Importing' : 'Import'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _CompactMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ClipMindColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ClipMindColors.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: ClipMindColors.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}

class _RecentSkeleton extends StatelessWidget {
  final bool compact;

  const _RecentSkeleton({this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => Container(
          width: 224,
          decoration: BoxDecoration(
            color: ClipMindColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ClipMindColors.borderColor),
          ),
          child: Column(
            children: [
              Expanded(child: Container(color: ClipMindColors.bgElevated)),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: ClipMindColors.bgElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: ClipMindColors.bgElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaDetails {
  final int durationMs;
  final String? thumbnailPath;

  const _MediaDetails({this.durationMs = 0, this.thumbnailPath});
}
