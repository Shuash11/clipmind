import 'dart:io';

import 'package:clipmind/app.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/core/router/app_router.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/thumbnail_service.dart';
import 'package:clipmind/data/services/updates/github_release_checker.dart';
import 'package:clipmind/data/services/updates/release_info.dart';
import 'package:clipmind/domain/usecases/import_video_usecase.dart';
import 'package:clipmind/features/providers/data/catalog/provider_catalog.dart';
import 'package:clipmind/features/providers/data/provider_platform_riverpod.dart';
import 'package:clipmind/features/providers/data/provider_registry_impl.dart';
import 'package:clipmind/features/providers/domain/contracts/model_provider_adapter.dart';
import 'package:clipmind/features/providers/domain/provider_platform_bootstrap.dart';
import 'package:clipmind/presentation/editor/editor_screen.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/clip_block.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/track_row.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/update_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// `show MediaKit` only: media_kit also exports a `Track` that collides with
// the clipmind project model.
import 'package:media_kit/media_kit.dart' show MediaKit;

/// Cycle 15 Phase A: editor timeline layout on the REAL Windows app.
///
/// The host-side `test/widget/editor_layout_matrix_test.dart` locks the
/// geometry with widget tests; this device smoke proves the same contract
/// survives the production editor mount (real routers, providers, player):
///
/// - at 1280x720 (the app default), the Video row's [ClipBlock] renders with
///   a >= 48px box OR the tracks region is in scrollable mode (the additive
///   `timeline-tracks-scroll` key), never a sliver row;
/// - at 1920x1080, all four [TrackRow]s render at >= 48px.
///
/// Assertions use rendered sizes ([WidgetTester.getSize]), not finders alone,
/// so a 26px sliver regression fails loudly. The fixture is built with the
/// real import mapping over a synthesized 2s clip; the repository is an
/// in-memory fake, so the run never writes through path_provider. The FFmpeg
/// gate mirrors `integration_test/editor_core_path_smoke_test.dart`:
/// `markTestSkipped` when the binaries are absent.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Same startup order as `lib/main.dart`: the shared mpv-backed Player is
  // created when the editor mounts, so media_kit must be initialized first.
  MediaKit.ensureInitialized();

  testWidgets(
    'Windows editor timeline layout: 1280x720 keeps rows readable (>= 48px '
    'ClipBlock) or scrollable',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
      final resolver = FfmpegBinaryResolver();
      final ffmpeg = resolver.resolveFfmpeg();
      final ffprobeBinary = resolver.resolveFfprobe();
      if (ffmpeg == null || ffprobeBinary == null) {
        markTestSkipped('ffmpeg/ffprobe not on PATH');
        return;
      }

      await _pumpEditorAt(
        tester,
        ffmpeg: ffmpeg,
        surface: const Size(1280, 720),
      );

      expect(find.byType(EditorScreen), findsOneWidget);
      expect(find.byType(TimelineView), findsOneWidget);
      expect(find.byType(ClipBlock), findsOneWidget);
      expect(find.byType(TrackRow), findsNWidgets(4));

      final clip = tester.getSize(find.byType(ClipBlock));
      final timeline = tester.getSize(find.byType(TimelineView));
      final scrollMode = find
          .byKey(const ValueKey('timeline-tracks-scroll'))
          .evaluate()
          .isNotEmpty;
      debugPrint(
        'c15-layout 1280x720: timeline=${timeline.height.toStringAsFixed(2)} '
        'clipBlock=${clip.height.toStringAsFixed(2)} scrollKey=$scrollMode',
      );

      expect(
        clip.height >= 48 - 0.01 || scrollMode,
        isTrue,
        reason:
            'at 1280x720 the Video ClipBlock must render >= 48px '
            '(got ${clip.height}) or the tracks region must be scrollable',
      );
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    },
  );

  testWidgets(
    'Windows editor timeline layout: 1920x1080 renders all four track rows '
    'at >= 48px',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
      final resolver = FfmpegBinaryResolver();
      final ffmpeg = resolver.resolveFfmpeg();
      final ffprobeBinary = resolver.resolveFfprobe();
      if (ffmpeg == null || ffprobeBinary == null) {
        markTestSkipped('ffmpeg/ffprobe not on PATH');
        return;
      }

      await _pumpEditorAt(
        tester,
        ffmpeg: ffmpeg,
        surface: const Size(1920, 1080),
      );

      expect(find.byType(EditorScreen), findsOneWidget);
      expect(find.byType(TimelineView), findsOneWidget);
      expect(find.byType(ClipBlock), findsOneWidget);
      expect(find.byType(TrackRow), findsNWidgets(4));

      final rows = <double>[
        for (var index = 0; index < 4; index++)
          tester.getSize(find.byType(TrackRow).at(index)).height,
      ];
      final clip = tester.getSize(find.byType(ClipBlock));
      final timeline = tester.getSize(find.byType(TimelineView));
      debugPrint(
        'c15-layout 1920x1080: timeline=${timeline.height.toStringAsFixed(2)} '
        'rows=${rows.map((h) => h.toStringAsFixed(2)).join(',')} '
        'clipBlock=${clip.height.toStringAsFixed(2)}',
      );

      for (var index = 0; index < rows.length; index++) {
        expect(
          rows[index] >= 48 - 0.01,
          isTrue,
          reason: 'track row $index must render >= 48px (got ${rows[index]})',
        );
      }
      expect(clip.height >= 48 - 0.01, isTrue);
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    },
  );
}

/// Boots the real app at [surface], navigates to the fixture project's editor
/// and waits for the clip label to render. The fixture project/repository are
/// in-memory only.
Future<void> _pumpEditorAt(
  WidgetTester tester, {
  required String ffmpeg,
  required Size surface,
}) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'clipmind_editor_layout_',
  );
  addTearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  final sourcePath =
      '${tempDir.path}${Platform.pathSeparator}layout_fixture.mp4';
  if (!await _synthesizeClip(ffmpeg, sourcePath)) {
    markTestSkipped('could not synthesize source clip');
    return;
  }

  final ffprobe = FfprobeService();
  final importUseCase = ImportVideoUseCase(
    ffprobe,
    ThumbnailService(ffprobe),
  );
  final metadata =
      await ffprobe.extractMetadata(sourcePath) ??
      const VideoMetadata(
        durationMs: 2000,
        width: 320,
        height: 240,
        fps: 30,
        codec: 'h264',
        hasAudio: true,
        bitrate: 0,
      );

  final fixture = _buildFixtureProject(importUseCase, sourcePath, metadata);
  final clipLabel = fixture.tracks.single.clips.single.label!;
  final repository = _FakeProjectRepository(db: database, project: fixture);

  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        projectRepositoryProvider.overrideWithValue(repository),
        providerPlatformBootstrapResultProvider.overrideWithValue(
          _offlineProviderBootstrap(),
        ),
        githubReleaseCheckerProvider.overrideWithValue(
          _OfflineGithubReleaseChecker(),
        ),
      ],
      child: const ClipMindApp(),
    ),
  );
  await _pumpFrames(tester);

  appRouter.go(editorPath.replaceAll(':projectId', fixture.id));
  await _pumpUntil(tester, find.byType(EditorScreen));
  await _pumpUntil(tester, find.text(clipLabel));
}

/// Unmounts the editor so the shared Player and controllers dispose before
/// the binding finishes (the existing smoke's deterministic teardown).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 16));
  expect(tester.takeException(), isNull);
}

/// Synthesize a 2s 320x240 `testsrc` + `sine` clip. True when ffmpeg exited
/// 0 and the file exists (the `editor_core_path_smoke_test.dart` pattern).
Future<bool> _synthesizeClip(String ffmpegBinary, String outputPath) async {
  final result = await Process.run(ffmpegBinary, [
    '-hide_banner',
    '-y',
    '-f',
    'lavfi',
    '-i',
    'testsrc=s=320x240:r=30:d=2',
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=440:duration=2',
    '-shortest',
    '-c:v',
    'libx264',
    '-pix_fmt',
    'yuv420p',
    '-c:a',
    'aac',
    '-ar',
    '44100',
    '-t',
    '2',
    outputPath,
  ]);
  return result.exitCode == 0 && File(outputPath).existsSync();
}

/// Build the in-memory fixture through the real import mapping: a video
/// track with one clip spanning the probed metadata duration.
Project _buildFixtureProject(
  ImportVideoUseCase importUseCase,
  String sourcePath,
  VideoMetadata metadata,
) {
  const trackId = 'layout-smoke-track';
  final project = Project(
    id: 'layout-smoke-project',
    name: 'Layout Smoke',
    createdAt: DateTime(2026, 10, 10),
    updatedAt: DateTime(2026, 10, 10),
    durationMs: metadata.durationMs,
    tracks: const [Track(id: trackId, type: TrackType.video, label: 'Video')],
  );
  final clip = importUseCase.createClipFromResult(
    sourcePath,
    metadata,
    trackId: trackId,
  );
  return importUseCase.addClipToProject(project, clip);
}

/// In-memory stand-in for the real repository: returns the fixture project,
/// records [loadFromId] calls, and never writes through path_provider.
final class _FakeProjectRepository extends ProjectRepository {
  _FakeProjectRepository({required AppDatabase db, required this.project})
    : super(db);

  final Project project;
  final List<String> loadedIds = [];

  @override
  Future<Project?> loadFromId(String id) async {
    loadedIds.add(id);
    return id == project.id ? project : null;
  }

  @override
  Future<List<Project>> listRecent() async => const [];

  @override
  Future<void> save(Project saved) async {}
}

Success<ProviderPlatformBootstrapResult> _offlineProviderBootstrap() =>
    Success<ProviderPlatformBootstrapResult>(
      ProviderPlatformBootstrapResult(
        ProviderRegistryImpl(
          definitions: ProviderCatalog.presets,
          adapters: const <String, ModelProviderAdapter>{},
        ),
      ),
    );

final class _OfflineGithubReleaseChecker extends GithubReleaseChecker {
  @override
  Future<ReleaseInfo?> checkForUpdate() async => null;
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 4}) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Bounded frame pump: waits for [finder] to appear (or disappear when
/// [present] is false) without `pumpAndSettle`, which can hang on the live
/// player/animation streams.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  bool present = true,
  int maxFrames = 300,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    if (finder.evaluate().isNotEmpty == present) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail(
    present
        ? 'Timed out waiting for $finder'
        : 'Timed out waiting for $finder to disappear',
  );
}
