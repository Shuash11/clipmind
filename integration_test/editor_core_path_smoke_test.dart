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
import 'package:clipmind/state/player_providers.dart';
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

/// Cycle 8 Phase 2: the editor core-path device smoke.
///
/// Proves on the real Windows app that navigating to a project mounts the
/// editor, the timeline renders the fixture project's track/clip, and the
/// Export action-bar button opens (and dismisses) the export dialog.
///
/// The fixture project is built with the real import mapping
/// ([ImportVideoUseCase.createClipFromResult] + [ImportVideoUseCase
/// .addClipToProject]) over a synthesized 2s clip; the real repository is
/// replaced by an in-memory fake, so the device run never writes through
/// path_provider into the host app-support directory.
///
/// The FFmpeg gate mirrors `test/integration/core_path_seam_test.dart`:
/// resolve the real binaries via [FfmpegBinaryResolver] and
/// `markTestSkipped` when either is absent, so machines without FFmpeg exit
/// clean. The host `flutter test` run discovers `test/` only, so this file
/// is device-run by design: `flutter test integration_test/<file> -d windows`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Same startup order as `lib/main.dart`: the shared mpv-backed Player is
  // created when the editor mounts, so media_kit must be initialized first.
  MediaKit.ensureInitialized();

  testWidgets(
    'Windows editor core path: open project -> timeline renders -> export '
    'dialog opens and dismisses',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
      final resolver = FfmpegBinaryResolver();
      final ffmpeg = resolver.resolveFfmpeg();
      final ffprobeBinary = resolver.resolveFfprobe();
      if (ffmpeg == null || ffprobeBinary == null) {
        markTestSkipped('ffmpeg/ffprobe not on PATH');
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp(
        'clipmind_editor_smoke_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final sourcePath =
          '${tempDir.path}${Platform.pathSeparator}editor_smoke_fixture.mp4';
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

      await tester.binding.setSurfaceSize(const Size(1400, 900));
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

      // Programmatic navigation through the real app router: the same
      // `/editor/:projectId` entry the hub's recent-project card uses.
      appRouter.go(editorPath.replaceAll(':projectId', fixture.id));

      // Editor mounts immediately; wait for the loaded project to render.
      await _pumpUntil(tester, find.byType(EditorScreen));
      expect(find.byType(EditorScreen), findsOneWidget);
      await _pumpUntil(tester, find.text(clipLabel));

      // The repository seam was exercised with the fixture id.
      expect(repository.loadedIds, equals([fixture.id]));

      // The real load path pointed the shared player at the fixture media
      // (preview engaged; no fallback used).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EditorScreen)),
      );
      expect(container.read(currentVideoPathProvider), equals(sourcePath));

      // Timeline: the fixture's video track/clip renders (one ClipBlock) and
      // the other three track rows render empty.
      expect(find.byType(TimelineView), findsOneWidget);
      expect(find.byType(ClipBlock), findsOneWidget);
      expect(find.text(clipLabel), findsOneWidget);
      expect(find.text('No clips'), findsNWidgets(3));

      // Export entry point: the top action bar button opens the dialog.
      final exportButton = find.text('Export');
      expect(exportButton, findsOneWidget);
      await tester.tap(exportButton);
      await _pumpUntil(tester, find.text('Export Project'));
      expect(find.text('Export Project'), findsOneWidget);

      // Dismiss through the barrier and land back on the editor.
      await tester.tapAt(const Offset(8, 8));
      await _pumpUntil(tester, find.text('Export Project'), present: false);
      expect(find.text('Export Project'), findsNothing);
      expect(find.text('Export'), findsOneWidget);
      expect(find.byType(TimelineView), findsOneWidget);

      expect(tester.takeException(), isNull);

      // Deterministic teardown: unmount so the shared Player and the
      // editor controllers dispose before the binding finishes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    },
  );
}

/// Synthesize a 2s 320x240 `testsrc` + `sine` clip. True when ffmpeg exited
/// 0 and the file exists (the `test/integration/core_path_seam_test.dart`
/// pattern).
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
  const trackId = 'editor-smoke-track';
  final project = Project(
    id: 'editor-smoke-project',
    name: 'Editor Smoke',
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
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
/// records [loadFromId] calls, and never writes through path_provider — the
/// device test leaves the host's app-support directory untouched.
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
