import 'dart:async';

import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/runtime/local_smoke_coordinator.dart';
import 'package:clipmind/core/runtime/local_smoke_launch_configuration.dart';
import 'package:clipmind/core/runtime/local_smoke_reporter.dart';
import 'package:clipmind/core/theme/clipmind_theme.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/features/projects/domain/entities/project_document.dart';
import 'package:clipmind/features/projects/domain/entities/project_track.dart';
import 'package:clipmind/features/projects/presentation/smoke_fixture_loader.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/features/providers/domain/provider_service_ids.dart';
import 'package:clipmind/features/providers/presentation/widgets/provider_profile_form.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LocalSmokeScreen extends StatefulWidget {
  const LocalSmokeScreen({
    super.key,
    required this.configuration,
    required this.loader,
    required this.coordinator,
    required this.providerInitialization,
  });

  factory LocalSmokeScreen.forConfiguration({
    Key? key,
    required LocalSmokeLaunchConfiguration configuration,
    required Result<ProviderPlatformBootstrapResult> providerInitialization,
  }) => LocalSmokeScreen(
    key: key,
    configuration: configuration,
    loader: FileSmokeFixtureLoader(),
    coordinator: LocalSmokeCoordinator(
      reporter: FileLocalSmokeReporter(configuration.report),
    ),
    providerInitialization: providerInitialization,
  );

  final LocalSmokeLaunchConfiguration configuration;
  final SmokeFixtureLoader loader;
  final LocalSmokeCoordinator coordinator;
  final Result<ProviderPlatformBootstrapResult> providerInitialization;

  @override
  State<LocalSmokeScreen> createState() => _LocalSmokeScreenState();
}

final class _LocalSmokeScreenState extends State<LocalSmokeScreen> {
  _LocalSmokeScreenStatus _status = _LocalSmokeScreenStatus.loading;
  ProjectDocument? _document;
  FlutterExceptionHandler? _previousFlutterErrorHandler;

  @override
  void initState() {
    super.initState();
    _previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _previousFlutterErrorHandler?.call(details);
      unawaited(widget.coordinator.onFlutterError(details.exception));
    };
    unawaited(_loadFixture());
  }

  @override
  void dispose() {
    FlutterError.onError = _previousFlutterErrorHandler;
    super.dispose();
  }

  Future<void> _loadFixture() async {
    try {
      final result = await widget.loader.load(widget.configuration.fixture);
      if (result case Success<ProjectDocument>(:final value)) {
        if (!_hasRenderableClip(value) ||
            widget.providerInitialization
                is Failure<ProviderPlatformBootstrapResult>) {
          await widget.coordinator.onFlutterError(
            StateError('local_smoke_failed'),
          );
          if (mounted) setState(() => _status = _LocalSmokeScreenStatus.failed);
          return;
        }
        await widget.coordinator.onProjectLoaded();
        if (!mounted) return;
        setState(() {
          _document = value;
          _status = _LocalSmokeScreenStatus.loaded;
        });
        return;
      }
      await widget.coordinator.onFlutterError(
        (result as Failure<ProjectDocument>).error,
      );
    } catch (error) {
      await widget.coordinator.onFlutterError(error);
    }
    if (!mounted) return;
    setState(() => _status = _LocalSmokeScreenStatus.failed);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClipMindColors.bgBase,
    body: switch ((_status, _document)) {
      (_LocalSmokeScreenStatus.loaded, final ProjectDocument document) =>
        _LoadedLocalSmokeLayout(
          document: document,
          providerInitialization: widget.providerInitialization,
          onTimelineRendered: () {
            unawaited(widget.coordinator.onTimelineRendered());
          },
          onProvidersRendered: () {
            unawaited(widget.coordinator.onProvidersRendered());
          },
        ),
      _ => _LocalSmokeStatus(message: _statusMessage),
    },
  );

  String get _statusMessage => _status == _LocalSmokeScreenStatus.failed
      ? 'Unable to load local smoke fixture.'
      : 'Loading local smoke fixture…';

  bool _hasRenderableClip(ProjectDocument document) {
    final assetIds = document.currentState.assets
        .map((asset) => asset.id)
        .toSet();
    return document.currentState.tracks.any(
      (track) => track.clips.any((clip) => assetIds.contains(clip.assetId)),
    );
  }
}

enum _LocalSmokeScreenStatus { loading, loaded, failed }

final class _LocalSmokeStatus extends StatelessWidget {
  const _LocalSmokeStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: message.startsWith('Unable')
                ? ClipMindColors.statusError
                : ClipMindColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

final class _LoadedLocalSmokeLayout extends StatelessWidget {
  const _LoadedLocalSmokeLayout({
    required this.document,
    required this.providerInitialization,
    required this.onTimelineRendered,
    required this.onProvidersRendered,
  });

  final ProjectDocument document;
  final Result<ProviderPlatformBootstrapResult> providerInitialization;
  final VoidCallback onTimelineRendered;
  final VoidCallback onProvidersRendered;

  @override
  Widget build(BuildContext context) {
    final providerResult = _localProviderResult(providerInitialization);
    final project = _legacyProject(document);
    final profile = providerResult.value.activeProfile!;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: KeyedSubtree(
                    key: const ValueKey('timeline-data'),
                    child: TimelineView(
                      project: project,
                      projectDocument: document,
                      onRendered: onTimelineRendered,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 480,
                  child: ProviderProfileForm(
                    profile: profile,
                    onRendered: onProvidersRendered,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Success<ProviderPlatformBootstrapResult> _localProviderResult(
    Result<ProviderPlatformBootstrapResult> source,
  ) {
    final initialized =
        (source as Success<ProviderPlatformBootstrapResult>).value;
    final existing = initialized.profiles.where(
      (profile) => profile.providerId == customOpenAiCompatibleProviderId,
    );
    final profile = ProviderProfile(
      id: existing.isEmpty ? 'local-smoke-custom-profile' : existing.first.id,
      providerId: customOpenAiCompatibleProviderId,
      displayName: 'Local smoke custom provider',
      endpoint: Uri.parse('https://local-smoke.invalid/v1'),
      enabled: false,
    );
    return Success<ProviderPlatformBootstrapResult>(
      ProviderPlatformBootstrapResult(
        initialized.registry,
        profiles: [profile],
        activeProfileId: profile.id,
      ),
    );
  }

  Project _legacyProject(ProjectDocument document) {
    final assets = {
      for (final asset in document.currentState.assets) asset.id: asset,
    };
    final tracks = <Track>[
      for (final track in document.currentState.tracks)
        Track(
          id: track.id,
          type: switch (track.kind) {
            ProjectTrackKind.video => TrackType.video,
            ProjectTrackKind.audio => TrackType.audio,
            ProjectTrackKind.text => TrackType.text,
            ProjectTrackKind.fx => TrackType.fx,
          },
          clips: [
            for (final clip in track.clips)
              if (assets[clip.assetId] case final asset?)
                Clip(
                  id: clip.id,
                  trackId: track.id,
                  sourcePath: asset.sourcePath,
                  startMs: clip.startMs,
                  endMs: clip.endMs,
                  positionMs: clip.positionMs,
                  label: asset.displayName,
                  muted: clip.muted,
                ),
          ],
        ),
    ];
    final duration = <int>[
      for (final asset in assets.values) asset.durationMs,
      for (final track in document.currentState.tracks)
        for (final clip in track.clips) clip.positionMs + clip.durationMs,
    ].fold(1, (value, next) => next > value ? next : value);
    return Project(
      id: document.id,
      name: document.name,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
      sourceMediaPaths: assets.values.map((asset) => asset.sourcePath).toList(),
      tracks: tracks,
      durationMs: duration,
      outputDir: document.outputDirectory,
    );
  }
}
