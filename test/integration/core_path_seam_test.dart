import 'dart:io';

import 'package:clipmind/data/local/database/app_database.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'package:clipmind/data/models/export_options.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/repositories/project_repository.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_binary_resolver.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/thumbnail_service.dart';
import 'package:clipmind/domain/usecases/export_project_usecase.dart';
import 'package:clipmind/domain/usecases/import_video_usecase.dart';
import 'package:clipmind/domain/usecases/structural_edit_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cycle 8 self-improvement: the core-path seam.
///
/// One deterministic host test that drives the production chain end to end:
/// synthesize media -> import (ffprobe + thumbnail) -> build/persist a
/// project -> reload from disk -> structural trim (+ journaled op) ->
/// export through the real pipeline -> verify a real playable output.
///
/// The FFmpeg/ffprobe gate mirrors `test/unit/ffmpeg/export_live_gates_test.dart`:
/// resolve the real binaries via [FfmpegBinaryResolver] and `markTestSkipped`
/// when either is absent, so CI runners without FFmpeg stay green. All I/O
/// lives under [Directory.systemTemp]; no network.

/// Synthesize a 2s 320x240 `testsrc` + `sine` clip. True when ffmpeg exited
/// 0 and the file exists.
Future<bool> _synthAv(String binary, String out) async {
  final result = await Process.run(binary, [
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
    out,
  ]);
  return result.exitCode == 0 && File(out).existsSync();
}

/// path_provider stub: `getApplicationSupportDirectory` returns
/// [appSupportPath] so the real [ProjectRepository] writes its `.cmproj`
/// file into the test's temp tree instead of the host app-support dir.
void _mockPathProvider(String appSupportPath) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationSupportDirectory') {
            return appSupportPath;
          }
          return null;
        },
      );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'core-path seam: import -> persist -> reload -> trim -> export',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      final resolver = FfmpegBinaryResolver();
      final ffmpeg = resolver.resolveFfmpeg();
      final ffprobeBinary = resolver.resolveFfprobe();
      if (ffmpeg == null || ffprobeBinary == null) {
        markTestSkipped('ffmpeg/ffprobe not on PATH');
        return;
      }

      final tmp = await Directory.systemTemp.createTemp('clipmind_core_seam_');
      final db = AppDatabase(NativeDatabase.memory());
      final ffprobe = FfprobeService();
      final importUseCase = ImportVideoUseCase(
        ffprobe,
        ThumbnailService(ffprobe),
      );
      final exportUseCase = ExportProjectUseCase();
      final progress = <double>[];
      final progressSub = exportUseCase.progressStream.listen(progress.add);

      try {
        // 1. Synthesize the source media.
        final source = '${tmp.path}/source.mp4';
        if (!await _synthAv(ffmpeg, source)) {
          markTestSkipped('could not synthesize source clip');
          return;
        }

        // 2. Import seam: real ffprobe metadata + real thumbnail.
        final imported = await importUseCase.execute(source);
        expect(imported.success, isTrue, reason: imported.error);
        final metadata = imported.metadata;
        expect(metadata, isNotNull, reason: 'ffprobe must read metadata');
        expect(metadata!.durationMs, greaterThan(0));
        final thumbnail = imported.thumbnailPath;
        expect(thumbnail, isNotNull, reason: 'thumbnail must be produced');
        expect(File(thumbnail!).existsSync(), isTrue);

        // 3. Build + persist via the real repository, then reload.
        final now = DateTime(2026, 10, 8);
        const trackId = 'track_1';
        final project = Project(
          id: 'seam_project',
          name: 'CoreSeam',
          createdAt: now,
          updatedAt: now,
          durationMs: metadata.durationMs,
          tracks: const [
            Track(id: trackId, type: TrackType.video, label: 'Video'),
          ],
        );
        final clip = importUseCase.createClipFromResult(
          source,
          metadata,
          trackId: trackId,
        );
        final built = importUseCase.addClipToProject(project, clip);
        expect(built.sourceMediaPaths, equals([source]));
        expect(built.tracks.single.clips.single.sourcePath, source);
        expect(built.tracks.single.clips.single.endMs, metadata.durationMs);

        final appSupport = Directory('${tmp.path}/app_support')
          ..createSync(recursive: true);
        _mockPathProvider(appSupport.path);
        final repository = ProjectRepository(db);
        await repository.save(built);

        final reloaded = await repository.loadFromId(built.id);
        expect(reloaded, isNotNull, reason: 'project must reload from disk');
        final reloadedClip = reloaded!.tracks.single.clips.single;
        expect(reloaded.id, built.id);
        expect(reloaded.name, 'CoreSeam');
        expect(reloaded.durationMs, metadata.durationMs);
        expect(reloaded.sourceMediaPaths, equals([source]));
        expect(reloadedClip.id, clip.id);
        expect(reloadedClip.sourcePath, source);
        expect(reloadedClip.startMs, 0);
        expect(reloadedClip.endMs, metadata.durationMs);
        expect(reloadedClip.positionMs, 0);

        // 4. Timeline seam: trim the reloaded project and journal the op.
        final trimOp = EditOperation(
          id: 'op_trim',
          type: EditOperationType.trimClip,
          targetClipIds: [clip.id],
          params: {'clip_id': clip.id, 'start_ms': 200, 'end_ms': 1500},
          createdAt: now,
        );
        final trimmed = const StructuralEditUseCase().apply(trimOp, reloaded);
        expect(trimmed, isNotNull, reason: 'trim must apply to the clip');
        final trimmedClip = trimmed!.tracks.single.clips.single;
        expect(trimmedClip.startMs, 200);
        expect(trimmedClip.endMs, 1500);
        expect(trimmedClip.positionMs, 0, reason: 'trim must repin to 0');

        await db.saveEditOperation(trimmed.id, trimOp);
        final history = await db.getEditHistory(trimmed.id);
        expect(history.map((op) => op.id), contains('op_trim'));
        expect(history.single.type, EditOperationType.trimClip);

        // 5. Export seam: real pipeline, real playable output.
        final out = '${tmp.path}/export.mp4';
        final result = await exportUseCase.execute(
          trimmed,
          options: ExportOptions.defaults().copyWith(outputPath: out),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(
          result.success,
          isTrue,
          reason: 'export failed: ${result.error}',
        );
        final outFile = File(out);
        expect(outFile.existsSync(), isTrue);
        expect(outFile.lengthSync(), greaterThan(0));
        expect(progress, contains(1.0), reason: 'progress=$progress');
        final outMeta = await ffprobe.extractMetadata(out);
        expect(outMeta, isNotNull, reason: 'export must be probeable');
        expect(outMeta!.durationMs, greaterThan(0));
      } finally {
        await progressSub.cancel();
        exportUseCase.dispose();
        await db.close();
        await tmp.delete(recursive: true);
      }
    },
  );
}
