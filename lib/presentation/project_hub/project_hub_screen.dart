import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/core/router/app_router.dart';
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
    _initUpdateCheck();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initUpdateCheck() async {
    final info = await PackageInfo.fromPlatform();
    ref.read(updateNotifierProvider.notifier).checkForUpdate(
      currentVersion: '${info.version}+${info.buildNumber}',
    );
  }

  Future<void> _handleBrowse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      await _handleImportedFiles(result.files);
    }
  }

  Future<void> _handleImportedFiles(List<PlatformFile> files) async {
    final repository = ref.read(projectRepositoryProvider);
    for (final file in files) {
      final project = await repository.createNew(file.name);
      if (!mounted) return;
      context.go(editorPath.replaceAll(':projectId', project.id));
      break;
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDragActive = false);
    final repository = ref.read(projectRepositoryProvider);
    for (final file in details.files) {
      final project = await repository.createNew(file.name);
      if (!mounted) return;
      context.go(editorPath.replaceAll(':projectId', project.id));
      break;
    }
  }

  Future<void> _handleUploadUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isImporting = true);

    try {
      final dir = await _getImportDir();
      String? downloadedPath;

      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        final service = YouTubeImportService();
        downloadedPath = await service.import(url, dir.path);
      } else if (url.contains('drive.google.com')) {
        final service = GDriveImportService();
        downloadedPath = await service.import(url, '${dir.path}/gdrive_download.mp4');
      } else {
        final service = GDriveImportService();
        downloadedPath = await service.import(url, '${dir.path}/direct_download.mp4');
      }

      if (downloadedPath != null && mounted) {
        final repository = ref.read(projectRepositoryProvider);
        final name = url.split('/').last.split('?').first;
        final project = await repository.createNew(name);
        if (mounted) {
          context.go(editorPath.replaceAll(':projectId', project.id));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import failed. Check the URL and try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
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

  Future<void> _showImportUrlDialog(String sourceType) async {
    final dialogController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Import from $sourceType'),
        content: TextField(
          controller: dialogController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Paste $sourceType URL...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, dialogController.text.trim()),
            child: const Text('Import'),
          ),
        ],
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
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final projectsAsync = ref.watch(recentProjectsProvider);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('All Projects', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  projectsAsync.when(
                    data: (projects) => ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          return ListTile(
                            title: Text(project.name),
                            subtitle: Text(project.updatedAt.toString().split('.').first),
                            leading: const Icon(Icons.movie_outlined),
                            onTap: () {
                              Navigator.pop(ctx);
                              context.go(editorPath.replaceAll(':projectId', project.id));
                            },
                          );
                        },
                      ),
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: $e'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('ClipMind', style: theme.textTheme.displaySmall),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UploadDropzone(
                    onBrowse: _handleBrowse,
                    onDragEntered: (_) => setState(() => _isDragActive = true),
                    onDragExited: (_) => setState(() => _isDragActive = false),
                    onDragDone: _handleDrop,
                    isDragActive: _isDragActive,
                  ),
                  const SizedBox(height: 24),
                  Text('Import from', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: ImportSourceCard(
                        icon: Icons.play_circle_fill,
                        label: 'YouTube',
                        source: 'youtube',
                        onTap: () => _showImportUrlDialog('YouTube'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: ImportSourceCard(
                        icon: Icons.cloud,
                        label: 'Google Drive',
                        source: 'gdrive',
                        onTap: () => _showImportUrlDialog('Google Drive'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: ImportSourceCard(
                        icon: Icons.link,
                        label: 'Paste a URL',
                        source: 'url',
                        onTap: () {
                          _urlController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _urlController.text.length,
                          );
                          _urlFocusNode.requestFocus();
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Projects', style: theme.textTheme.titleMedium),
                      TextButton(onPressed: _showAllProjects, child: const Text('View all')),
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
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Paste a video URL...',
                      suffixIcon: _isImporting
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.upload),
                              onPressed: _handleUploadUrl,
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
    return const SizedBox(
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
            const Icon(Icons.movie_creation_outlined,
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
