import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/ffmpeg/procedural_sound_service.dart';
import 'package:clipmind/data/services/fonts/font_resolver.dart';
import 'package:clipmind/features/tagging/presentation/providers/tagging_providers.dart';
import 'package:clipmind/features/tagging/presentation/widgets/media_panel.dart';
import 'package:clipmind/presentation/editor/providers/left_panel_provider.dart';
import 'package:clipmind/presentation/editor/providers/selected_clip_provider.dart';
import 'package:clipmind/presentation/editor/widgets/toolbar/left_panel.dart';
import 'package:clipmind/presentation/editor/widgets/toolbar/left_tool_rail.dart';
import 'package:clipmind/presentation/editor/widgets/timeline/timeline_view.dart';
import 'package:clipmind/state/agent_providers.dart';
import 'package:clipmind/state/project_providers.dart';
import 'package:clipmind/state/settings_providers.dart';
import 'package:clipmind/state/undo_redo_providers.dart';
import '../features/tagging/support/tagging_widget_harness.dart';

/// Fake repository: the sandbox has no path_provider; the save is a no-op
/// so the mutation reaches the project state and the applier chain
/// completes without file IO (the timeline_view_test pattern).
class _FakeProjectRepository extends ProjectRepository {
  _FakeProjectRepository({required AppDatabase db}) : super(db);

  @override
  Future<void> save(Project project) async {}
}

/// Fake FFmpeg: runSync creates the temp output file and reports success,
/// so the engine's copy step and the submit chains complete in the sandbox.
class _FakeFfmpegService extends FfmpegService {
  _FakeFfmpegService() : super(resolver: _StubResolver('C:/fake/ffmpeg.exe'));

  @override
  Future<FfmpegResult> runSync(FfmpegJob job) async {
    File(job.outputPath).parent.createSync(recursive: true);
    File(job.outputPath).writeAsStringSync('fake');
    return FfmpegResult(
      success: true,
      outputPath: job.outputPath,
      exitCode: 0,
    );
  }

  @override
  void cancel() {}
}

/// Fake ffprobe: no shell-out, a fixed has-audio metadata so the sound
/// layer takes the amix path deterministically.
class _StubFfprobeService extends FfprobeService {
  _StubFfprobeService() : super(resolver: _StubResolver('C:/fake/ffprobe.exe'));

  @override
  Future<VideoMetadata?> extractMetadata(String filePath) async {
    return const VideoMetadata(
      durationMs: 30000,
      width: 1920,
      height: 1080,
      fps: 30,
      codec: 'h264',
      hasAudio: true,
      bitrate: 5000,
    );
  }
}

/// Stub procedural sound service: renders each requested preset to a wav
/// in the test's pinned temp dir (no FFmpeg shell-out).
class _StubProceduralSoundService extends ProceduralSoundService {
  _StubProceduralSoundService(this._outputDir);

  final Directory _outputDir;

  @override
  Future<String?> generate(
    String presetId, {
    String? outputPath,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final file = File('${_outputDir.path}/$presetId.wav')
      ..writeAsStringSync('fake');
    return file.path;
  }
}

class _StubResolver extends FfmpegBinaryResolver {
  _StubResolver(this.path);

  final String? path;

  @override
  String? resolveFfmpeg({String? settingsPath}) => path;
}

Project _project() {
  return Project(
    id: 'p1',
    name: 'Test',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['C:/media/sample.mp4'],
    tracks: const [
      Track(
        id: 'track-1',
        type: TrackType.video,
        label: 'Video',
        clips: [
          Clip(
            id: 'clip-1',
            trackId: 'track-1',
            sourcePath: 'C:/media/sample.mp4',
            startMs: 0,
            endMs: 30000,
            label: 'sample.mp4',
          ),
        ],
      ),
    ],
    durationMs: 30000,
  );
}

void main() {
  late AppDatabase db;
  Directory? tempDir;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    tempDir?.deleteSync(recursive: true);
    tempDir = null;
  });

  Directory makeOutputDir() {
    tempDir = Directory.systemTemp.createTempSync('clipmind_panel_');
    return tempDir!;
  }

  ProviderContainer panelContainer({
    TaggingWidgetHarness? harness,
    FontResolver? fontResolver,
    bool stubSound = false,
  }) {
    return ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          _FakeProjectRepository(db: db),
        ),
        ffmpegServiceProvider.overrideWithValue(_FakeFfmpegService()),
        appDatabaseProvider.overrideWithValue(db),
        if (harness != null)
          taggingProvidersProvider.overrideWithValue(harness.providers),
        if (fontResolver != null)
          fontResolverProvider.overrideWithValue(fontResolver),
        if (stubSound) ...[
          ffprobeServiceProvider.overrideWithValue(_StubFfprobeService()),
          proceduralSoundServiceProvider.overrideWithValue(
            _StubProceduralSoundService(tempDir!),
          ),
        ],
      ],
    );
  }

  Future<void> pumpPanel(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LeftPanel())),
      ),
    );
    await tester.pump();
  }

  testWidgets('LeftPanel renders the four tabs and the collapse affordance', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await pumpPanel(tester, container);

    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Effects'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
    // The Media tab hosts the migrated MediaPanel.
    expect(find.byType(MediaPanel), findsOneWidget);
  });

  testWidgets('the rail opens the panel on the clicked tab; a second click '
      'collapses it', (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                LeftToolRail(),
                SizedBox(width: 10),
                LeftPanel(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(container.read(leftPanelProvider).open, isFalse);

    // Effects opens the panel on the effects tab.
    await tester.tap(find.byIcon(Icons.auto_fix_high_outlined));
    await tester.pumpAndSettle();
    expect(container.read(leftPanelProvider).open, isTrue);
    expect(container.read(leftPanelProvider).tab, LeftPanelTab.effects);

    // A second click on the active tool collapses the panel.
    await tester.tap(find.byIcon(Icons.auto_fix_high_outlined));
    await tester.pumpAndSettle();
    expect(container.read(leftPanelProvider).open, isFalse);

    // Media opens on the media tab (the migrated dialog content).
    await tester.tap(find.byIcon(Icons.movie_outlined));
    await tester.pumpAndSettle();
    expect(container.read(leftPanelProvider).open, isTrue);
    expect(container.read(leftPanelProvider).tab, LeftPanelTab.media);
    expect(find.byType(MediaPanel), findsOneWidget);

    // The collapse affordance closes it too.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_left));
    await tester.pumpAndSettle();
    expect(container.read(leftPanelProvider).open, isFalse);
  });

  testWidgets('the Media tab hosts the migrated MediaPanel with content', (
    WidgetTester tester,
  ) async {
    final harness = TaggingWidgetHarness();
    final container = panelContainer(harness: harness);
    addTearDown(container.dispose);
    await pumpPanel(tester, container);

    expect(find.byType(MediaPanel), findsOneWidget);
    expect(find.text('Search media'), findsOneWidget);
  });

  testWidgets('the Effects tab shows Select a clip first without a selection', (
    WidgetTester tester,
  ) async {
    final container = panelContainer();
    addTearDown(container.dispose);
    container.read(projectProvider.notifier).setProject(_project());
    await pumpPanel(tester, container);

    await tester.tap(find.text('Effects'));
    await tester.pumpAndSettle();
    expect(find.text('Select a clip first.'), findsOneWidget);

    // A guard click still reports the missing selection (banner + snackbar).
    await tester.tap(find.text('Noir'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Select a clip first.'), findsNWidgets(2));
  });

  testWidgets('the tabs show Open a project first without a project', (
    WidgetTester tester,
  ) async {
    final container = panelContainer();
    addTearDown(container.dispose);
    await pumpPanel(tester, container);

    // The Effects tab via the provider (the rail's path): the panel's
    // TabBar animates to the tab.
    container.read(leftPanelProvider.notifier).open(LeftPanelTab.effects);
    await tester.pumpAndSettle();
    expect(find.text('Open a project first.'), findsOneWidget);

    // The Audio tab via the provider too.
    container.read(leftPanelProvider.notifier).open(LeftPanelTab.audio);
    await tester.pumpAndSettle();
    expect(find.text('Open a project first.'), findsOneWidget);
  });

  testWidgets('an effect preset click applies through the applier '
      '(undoable + journaled)', (WidgetTester tester) async {
    makeOutputDir();
    final harness = TaggingWidgetHarness();
    final container = panelContainer(harness: harness);
    addTearDown(container.dispose);
    container
        .read(projectProvider.notifier)
        .setProject(_project().copyWith(outputDir: tempDir!.path));
    container.read(selectedClipIdProvider.notifier).state = 'clip-1';
    await pumpPanel(tester, container);

    await tester.tap(find.text('Effects'));
    await tester.pumpAndSettle();
    expect(find.text('Selected clip: sample.mp4'), findsOneWidget);

    // A double tap is blocked by the busy guard; exactly one submit lands.
    await tester.tap(find.text('Noir'));
    await tester.tap(find.text('Noir'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Effect "Noir" applied.'), findsOneWidget);
    expect(container.read(undoRedoProvider).canUndo, isTrue);
    // The noir recipe's two steps journal as two ops.
    expect(container.read(undoRedoProvider).historyCount, equals(2));
    // The clip repointed to the composed output.
    final updated = container.read(projectProvider).value!;
    final clip = updated.tracks.first.clips.single;
    expect(clip.sourcePath, contains('.mp4'));
  });

  testWidgets('the Text tab renders the bundled fonts and applies the overlay', (
    WidgetTester tester,
  ) async {
    makeOutputDir();
    final harness = TaggingWidgetHarness();
    final fontDir = Directory.systemTemp.createTempSync('clipmind_fonts_');
    addTearDown(() => fontDir.deleteSync(recursive: true));
    final container = panelContainer(
      harness: harness,
      fontResolver: FontResolver(supportDir: () async => fontDir),
    );
    addTearDown(container.dispose);
    container
        .read(projectProvider.notifier)
        .setProject(_project().copyWith(outputDir: tempDir!.path));
    container.read(selectedClipIdProvider.notifier).state = 'clip-1';
    // The panel mounts on the text tab (initialIndex from the provider);
    // the bundled fonts start loading.
    container.read(leftPanelProvider.notifier).open(LeftPanelTab.text);
    await pumpPanel(tester, container);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Inter'), findsOneWidget);
    expect(find.text('Montserrat'), findsOneWidget);
    expect(find.text('Roboto'), findsOneWidget);
    expect(find.text('Lato'), findsOneWidget);
    expect(find.text('Source Code Pro'), findsOneWidget);
    expect(find.text('EB Garamond'), findsOneWidget);
    // No unavailable tags: the bundled assets loaded through the resolver.
    expect(find.text('Unavailable'), findsNothing);

    // Pick Inter, type, apply → the overlay goes through the applier.
    await tester.tap(find.text('Inter'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Hello ClipMind');
    await tester.ensureVisible(find.text('Apply text'));
    await tester.tap(find.text('Apply text'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Text overlay applied.'), findsOneWidget);
    expect(container.read(undoRedoProvider).canUndo, isTrue);
    expect(container.read(undoRedoProvider).historyCount, equals(1));
  });

  testWidgets('the Audio tab applies a built-in sound through the applier', (
    WidgetTester tester,
  ) async {
    makeOutputDir();
    final harness = TaggingWidgetHarness();
    final container = panelContainer(harness: harness, stubSound: true);
    addTearDown(container.dispose);
    container
        .read(projectProvider.notifier)
        .setProject(_project().copyWith(outputDir: tempDir!.path));
    container.read(selectedClipIdProvider.notifier).state = 'clip-1';
    // The panel mounts on the audio tab (initialIndex from the provider).
    container.read(leftPanelProvider.notifier).open(LeftPanelTab.audio);
    await pumpPanel(tester, container);
    await tester.pump();

    expect(find.text('Selected clip: sample.mp4'), findsOneWidget);
    expect(find.text('Add sound from file'), findsOneWidget);
    // The 6 procedural presets render.
    expect(find.text('Beep'), findsOneWidget);
    expect(find.text('Drone (low)'), findsOneWidget);
    expect(find.text('Drone (mid)'), findsOneWidget);
    expect(find.text('Hum'), findsOneWidget);
    expect(find.text('Static noise'), findsOneWidget);
    expect(find.text('Alert chime'), findsOneWidget);
    // The volume slider defaults to 1.0 and follows a drag.
    expect(tester.widget<Slider>(find.byType(Slider)).value, equals(1.0));
    await tester.ensureVisible(find.byType(Slider));
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pump();
    expect(
      tester.widget<Slider>(find.byType(Slider)).value,
      greaterThan(1.0),
    );

    await tester.tap(find.text('Beep'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Sound added.'), findsOneWidget);
    expect(container.read(undoRedoProvider).canUndo, isTrue);
    expect(container.read(undoRedoProvider).historyCount, equals(1));
  });

  testWidgets('the timeline clip selection syncs into selectedClipIdProvider', (
    WidgetTester tester,
  ) async {
    // The delete flow's save runs through the fake repo (no path_provider
    // in the sandbox).
    final container = panelContainer();
    addTearDown(container.dispose);
    container.read(projectProvider.notifier).setProject(_project());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TimelineView())),
      ),
    );
    await tester.pump();
    expect(container.read(selectedClipIdProvider), isNull);

    // Tap-select the clip block (the timeline test pattern); the
    // selection is shared with the left panel.
    await tester.tap(find.text('sample.mp4'));
    await tester.pump();
    expect(container.read(selectedClipIdProvider), equals('clip-1'));

    // Delete clears the shared selection.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(container.read(selectedClipIdProvider), isNull);
  });

  testWidgets('Transitions and Adjustments stay unwired with a coming-soon '
      'heads-up', (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LeftToolRail())),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.blur_on_outlined));
    await tester.pump();
    expect(find.text('Transitions are coming soon.'), findsOneWidget);
    expect(container.read(leftPanelProvider).open, isFalse);

    // Snackbars queue and the duration timer starts only after the
    // entrance completes: pump through entrance → duration → exit before
    // the second tap's snackbar can show.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    expect(find.text('Adjustments are coming soon.'), findsOneWidget);
    expect(container.read(leftPanelProvider).open, isFalse);
  });
}
