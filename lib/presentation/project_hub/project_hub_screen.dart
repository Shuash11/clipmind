import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:clipmind/core/constants/release_notes.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/state/ffmpeg_providers.dart';
import 'package:clipmind/state/import_providers.dart';
import 'package:clipmind/state/player_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/update_providers.dart';
import 'package:clipmind/presentation/settings/widgets/update_dialog.dart';
import 'package:clipmind/presentation/shared_widgets/whats_new_dialog.dart';

import 'package:clipmind/data/services/import/youtube_import_service.dart';
import 'package:clipmind/data/services/import/url_import_service.dart';
import 'package:clipmind/data/models/app_settings.dart';
import 'package:clipmind/data/services/updates/update_result_reader.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'widgets/upload_dropzone.dart';
import 'widgets/import_source_card.dart';
import 'widgets/recent_project_card.dart';
import 'widgets/hub_top_bar.dart';
import 'widgets/blank_project_card.dart';
import 'widgets/yt_dlp_guidance_dialog.dart';

/// URL bar flow: [idle] accepts input, [checking] runs the YouTube
/// availability preflight, and [downloading] renders the service's
/// determinate progress plus a cancel action.
enum _UrlImportFlow { idle, checking, downloading }

/// True when [url] targets YouTube by host (`youtube.com`, `youtu.be`, and
/// their subdomains). Host-based so look-alike domains such as
/// `notyoutube.com` keep the direct-download path.
bool _isYouTubeUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host == 'youtube.com' ||
      host == 'youtu.be' ||
      host.endsWith('.youtube.com') ||
      host.endsWith('.youtu.be');
}

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

  /// URL-bar flow state; [_isImporting] stays the hub-wide busy lock.
  _UrlImportFlow _urlFlow = _UrlImportFlow.idle;
  double? _importProgress;

  /// Bumped on every start/cancel so a superseded attempt's late emissions
  /// and completion can never touch the UI (cancel, then a new import).
  int _importGeneration = 0;
  VoidCallback? _cancelActiveImport;
  StreamSubscription<String>? _importErrorSub;
  StreamSubscription<double>? _importProgressSub;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_handleUrlChanged);
    _initUpdateCheck();
    _checkWhatsNew();
  }

  @override
  void dispose() {
    // A pending import's child keeps running, but its streams must not
    // call back into a disposed state.
    unawaited(_importErrorSub?.cancel());
    unawaited(_importProgressSub?.cancel());
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
      // Consume the last update result (written by the install helper
      // before relaunching): a failed/mismatched update surfaces here on
      // the next launch instead of looping silently.
      final result =
          await const UpdateResultReader().consume(
        currentVersion: info.version,
      );
      if (result != null && result.message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message!),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      if (!mounted) return;
      ref
          .read(updateNotifierProvider.notifier)
          .checkForUpdate(currentVersion: info.version);
    } catch (_) {
      // Update checks should never block the hub from loading.
    }
  }

  /// "What's new" after an update: gated on a version change with notes
  /// for the current version. First run persists silently — no dialog.
  Future<void> _checkWhatsNew() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final current = info.version;
      // Wait for the persisted settings: a stale read would silently
      // overwrite lastSeenVersion and skip the dialog.
      final settings = await _awaitLoadedSettings();
      final lastSeen = settings?.lastSeenVersion ?? '';
      if (lastSeen == '') {
        await _updateSettings((s) => s.copyWith(lastSeenVersion: current));
        return;
      }
      if (lastSeen == current) return;
      final notes = releaseNotes[current];
      if (notes == null) return;
      if (!mounted) return;
      await WhatsNewDialog.show(
        context,
        version: current,
        notes: notes,
      );
      if (!mounted) return;
      await _updateSettings((s) => s.copyWith(lastSeenVersion: current));
    } catch (_) {
      // What's-new should never block the hub from loading.
    }
  }

  /// Wait for [settingsProvider] to leave loading (the hub opens before
  /// the settings have resolved; one-shot listen with fireImmediately).
  Future<AppSettings?> _awaitLoadedSettings() {
    final completer = Completer<AppSettings?>();
    final sub = ref.listenManual<AsyncValue<AppSettings>>(
      settingsProvider,
      (_, next) {
        if (!next.isLoading && !completer.isCompleted) {
          completer.complete(next.value);
        }
      },
      fireImmediately: true,
    );
    unawaited(completer.future.whenComplete(sub.close));
    return completer.future;
  }

  /// Read + update through [settingsProvider]; persists via
  /// `SettingsRepository.save`. No-op when settings have not loaded yet.
  Future<void> _updateSettings(AppSettings Function(AppSettings) mutate) async {
    try {
      final current = ref.read(settingsProvider).value;
      if (current == null) return;
      await ref.read(settingsProvider.notifier).update(mutate(current));
    } catch (_) {}
  }

  Future<void> _handleBrowse() async {
    if (_isImporting) return;
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (files.isNotEmpty) {
      await _handleImportedFiles(files);
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

    if (!_isYouTubeUrl(url)) {
      await _startImport(url);
      return;
    }

    // YouTube preflight: never spawn yt-dlp for a binary that does not
    // answer. The probe instance is reused for the import when available.
    setState(() {
      _isImporting = true;
      _urlFlow = _UrlImportFlow.checking;
    });
    final service = ref.read(youtubeImportServiceFactoryProvider)();
    final availability = await service.checkAvailability();
    if (!mounted) return;
    if (!availability.isAvailable) {
      setState(() {
        _isImporting = false;
        _urlFlow = _UrlImportFlow.idle;
      });
      // Recovery path for a previous runtime missing-binary failure too:
      // the dialog explains the standalone install and links the official
      // release page.
      await YtDlpGuidanceDialog.show(
        context,
        onLaunchFailed: _handleGuidanceLaunchFailed,
      );
      return;
    }
    await _startImport(url, youtubeService: service);
  }

  void _handleGuidanceLaunchFailed() {
    if (!mounted) return;
    _showImportError(
      'Could not open the download page — find yt-dlp at '
      'github.com/yt-dlp/yt-dlp/releases',
    );
  }

  /// Downloads [url] with the probed [youtubeService] (YouTube) or a fresh
  /// [UrlImportService] (direct link), streaming determinate progress into
  /// the URL bar. A cancelled attempt's late emissions and completion are
  /// dropped by [_importGeneration].
  Future<void> _startImport(
    String url, {
    YouTubeImportService? youtubeService,
  }) async {
    final generation = ++_importGeneration;
    setState(() {
      _isImporting = true;
      _urlFlow = _UrlImportFlow.downloading;
      _importProgress = null;
    });

    String? downloadedPath;
    String? reportedError;
    StreamSubscription<String>? errorSub;
    StreamSubscription<double>? progressSub;

    void trackError(String message) {
      if (generation != _importGeneration) return;
      reportedError ??= message;
      if (mounted) _showImportError(message);
    }

    try {
      final dir = await _getImportDir();
      if (!mounted || generation != _importGeneration) return;

      // NOTE: as before the refactor, the import future is created before
      // subscribing: both services create their controllers synchronously
      // inside import(), so subscribing earlier would attach to
      // Stream.empty().
      final Future<String?> pending;
      final Stream<String> errors;
      final Stream<double> progress;
      final VoidCallback onCancel;
      if (youtubeService != null) {
        pending = youtubeService.import(url, dir.path);
        errors = youtubeService.errors;
        progress = youtubeService.progress;
        onCancel = youtubeService.cancel;
      } else {
        final service = ref.read(urlImportServiceFactoryProvider)();
        pending = service.import(url, '${dir.path}/direct_download.mp4');
        errors = service.errors;
        progress = service.progress;
        onCancel = service.cancel;
      }

      _cancelActiveImport = onCancel;
      errorSub = errors.listen(trackError);
      progressSub = progress.listen((value) {
        if (generation != _importGeneration || !mounted) return;
        setState(() => _importProgress = value.clamp(0.0, 1.0));
      });
      _importErrorSub = errorSub;
      _importProgressSub = progressSub;

      downloadedPath = await pending;

      if (generation != _importGeneration) return;
      if (downloadedPath != null && mounted) {
        // The download is done — nothing left to cancel. Hide the cancel
        // affordance before the open step (ffprobe + thumbnail can take
        // seconds); _isImporting stays true so the field and submit remain
        // disabled until the finally resets the bar.
        setState(() {
          _urlFlow = _UrlImportFlow.idle;
          _importProgress = null;
        });
        await _openProjectForMedia(
          name: _fileNameFromPath(downloadedPath),
          path: downloadedPath,
          manageBusy: false,
        );
      } else if (mounted && reportedError == null) {
        _showImportError('Import failed. Check the URL and try again.');
      }
    } catch (_) {
      if (generation == _importGeneration && mounted) {
        _showImportError('Import failed. Check the URL and try again.');
      }
    } finally {
      await errorSub?.cancel();
      await progressSub?.cancel();
      if (generation == _importGeneration && mounted) {
        setState(() {
          _isImporting = false;
          _urlFlow = _UrlImportFlow.idle;
          _importProgress = null;
          _importErrorSub = null;
          _importProgressSub = null;
          _cancelActiveImport = null;
        });
      }
    }
  }

  /// Cancels the in-flight download: invalidates the attempt first (so its
  /// late completion, errors, and progress cannot reach the UI), then drops
  /// the subscriptions and kills the child. The bar returns to idle with a
  /// single notice — the direct-download service's own "Download cancelled"
  /// error lands on a stale generation and is dropped.
  void _handleCancelImport() {
    if (_urlFlow != _UrlImportFlow.downloading) return;
    _importGeneration++;
    final cancel = _cancelActiveImport;
    _cancelActiveImport = null;
    unawaited(_importErrorSub?.cancel());
    _importErrorSub = null;
    unawaited(_importProgressSub?.cancel());
    _importProgressSub = null;
    cancel?.call();
    setState(() {
      _isImporting = false;
      _urlFlow = _UrlImportFlow.idle;
      _importProgress = null;
    });
    _showImportError('Download cancelled');
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

  /// Blank-project entry point: create with empty media, open the editor.
  Future<void> _createBlankProject() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final repository = ref.read(projectRepositoryProvider);
      final project = await repository.createNew('Blank project');
      if (!mounted) return;
      ref.read(projectProvider.notifier).setProject(project);
      context.go(editorPath.replaceAll(':projectId', project.id));
    } catch (_) {
      if (mounted) {
        _showImportError('Could not create the project.');
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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
      } else if (next.status == UpdateStatus.upToDate &&
          previous?.status == UpdateStatus.checking) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You're up to date!"),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
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
            HubTopBar(
              onSettings: () => context.go(settingsPath),
              onNewProject: _handleBrowse,
            ),
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
              urlFlow: _urlFlow,
              progress: _importProgress,
              hasUrl: hasUrl,
              onClear: () => _urlController.clear(),
              onImport: _handleUploadUrl,
              onCancel: _handleCancelImport,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSources(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth;
    final isNarrow = maxWidth < 760;
    final cardWidth = isNarrow ? maxWidth : (maxWidth - 12) / 2;

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
            subtitle: 'Paste a YouTube link to import the video',
            onTap: () => _showImportUrlDialog('YouTube'),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: ImportSourceCard(
            icon: Icons.link_rounded,
            label: 'Paste a URI',
            source: 'url',
            subtitle: 'Any direct video link from the web',
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
        itemCount: projects.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return BlankProjectCard(
              key: const ValueKey('blank-project-card'),
              onTap: _createBlankProject,
            );
          }
          return RecentProjectCard(project: projects[index - 1]);
        },
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

/// Centered hero: violet tile, headline and two-line supporting copy.
class _HubIntro extends StatelessWidget {
  final ThemeData theme;

  const _HubIntro({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ClipMindColors.accentPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ClipMindColors.accentPrimary.withValues(alpha: 0.24),
              ),
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: ClipMindColors.accentPrimary,
              size: 22,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'What are we editing today?',
            style: theme.textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Text(
              'Upload a video, paste a link, or pick a recent project — your AI assistant is ready to help.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: ClipMindColors.textMuted,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: ClipMindColors.accentPrimary,
            ),
            child: Text(actionLabel!, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}

class _UrlImportBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isImporting;
  final _UrlImportFlow urlFlow;
  final double? progress;
  final bool hasUrl;
  final VoidCallback onClear;
  final VoidCallback onImport;
  final VoidCallback onCancel;

  const _UrlImportBar({
    required this.controller,
    required this.focusNode,
    required this.isImporting,
    required this.urlFlow,
    required this.progress,
    required this.hasUrl,
    required this.onClear,
    required this.onImport,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pillBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(color: ClipMindColors.borderColor),
    );
    final pillFocusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: const BorderSide(
        color: ClipMindColors.accentPrimary,
        width: 1.5,
      ),
    );
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
                    hintText:
                        'Paste a video URL — YouTube, Google Drive, or direct link...',
                    filled: true,
                    fillColor: ClipMindColors.bgElevated,
                    border: pillBorder,
                    enabledBorder: pillBorder,
                    focusedBorder: pillFocusBorder,
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
              if (urlFlow == _UrlImportFlow.downloading)
                _buildProgressCluster(theme)
              else
                _buildSubmitButton(
                  isChecking: urlFlow == _UrlImportFlow.checking,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Idle/checking submit affordance. While any hub operation is in flight
  /// the button stays disabled; a YouTube preflight reads "Checking".
  Widget _buildSubmitButton({required bool isChecking}) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: isImporting ? null : onImport,
        style: FilledButton.styleFrom(
          backgroundColor: ClipMindColors.bgElevated,
          foregroundColor: ClipMindColors.textPrimary,
        ),
        icon: isImporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_rounded, size: 18),
        label: Text(
          isImporting ? (isChecking ? 'Checking' : 'Importing') : 'Import',
        ),
      ),
    );
  }

  /// Downloading affordance: label + helper text above a compact 4px track
  /// (text stays outside the bar), with cancel replacing the submit button.
  /// [LinearProgressIndicator] is determinate whenever the service has
  /// reported a value, indeterminate until then.
  Widget _buildProgressCluster(ThemeData theme) {
    final value = progress;
    final percent = value == null ? null : (value * 100).round();
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 208,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  percent == null ? 'Downloading…' : 'Downloading… $percent%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ClipMindColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: const ValueKey('url-import-progress'),
                    value: value,
                    minHeight: 4,
                    backgroundColor: ClipMindColors.bgElevated,
                    valueColor: const AlwaysStoppedAnimation(
                      ClipMindColors.accentPrimary,
                    ),
                    semanticsLabel: 'Download progress',
                    semanticsValue: percent == null ? null : '$percent%',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Cancel download',
            icon: const Icon(Icons.close_rounded),
            onPressed: onCancel,
          ),
        ],
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
