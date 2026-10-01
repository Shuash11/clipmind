import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipmind/data/models/clip.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/track.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/presentation/shared_widgets/export_dialog.dart';
import 'package:clipmind/state/export_providers.dart';
import 'package:clipmind/state/ffmpeg_providers.dart';

/// Cycle 6 Phase 2 Step 2 (D1): export dialog states + provider wiring.
///
/// The dialog is pumped with a ProviderScope overriding
/// `ffmpegServiceProvider` with a capturing fake, so the REAL use case
/// (via `exportUseCaseProvider`) drives the real progress wiring. The
/// FilePicker channel is never tapped (no output-path picking).
///
/// Two fakes: [_GatedFfmpeg] parks mid-run behind a completer so the
/// progress UI and Cancel are observable; [_FastFfmpeg] completes
/// immediately for the success path.
class _GatedFfmpeg extends FfmpegService {
  _GatedFfmpeg() : super(tempDir: Directory.systemTemp.path);

  FfmpegJob? lastJob;
  Completer<void> gate = Completer<void>();
  final List<String> createdFiles = [];

  @override
  Stream<FfmpegProgress> run(FfmpegJob job) async* {
    lastJob = job;
    yield const FfmpegProgress(
      percent: 0.1,
      outTimeMs: 100,
      speed: '',
      status: 'running',
    );
    await gate.future;
    final out = File(job.outputPath);
    out.parent.createSync(recursive: true);
    out.writeAsStringSync('fake-export');
    createdFiles.add(job.outputPath);
    yield FfmpegProgress(
      percent: 1.0,
      outTimeMs: job.expectedDurationMs,
      speed: '',
      status: 'complete',
    );
  }

  @override
  void cancel() {}
}

class _FastFfmpeg extends FfmpegService {
  _FastFfmpeg() : super(tempDir: Directory.systemTemp.path);

  FfmpegJob? lastJob;
  final List<String> createdFiles = [];

  @override
  Stream<FfmpegProgress> run(FfmpegJob job) async* {
    lastJob = job;
    yield const FfmpegProgress(
      percent: 0.5,
      outTimeMs: 100,
      speed: '',
      status: 'running',
    );
    final out = File(job.outputPath);
    out.parent.createSync(recursive: true);
    out.writeAsStringSync('fake-export');
    createdFiles.add(job.outputPath);
    yield FfmpegProgress(
      percent: 1.0,
      outTimeMs: job.expectedDurationMs,
      speed: '',
      status: 'complete',
    );
  }

  @override
  void cancel() {}
}

Project _project() {
  return Project(
    id: 'p1',
    name: 'WidgetExportProbe',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceMediaPaths: const ['/v/a.mp4'],
    tracks: const [
      Track(
        id: 't1',
        type: TrackType.video,
        label: 'V',
        clips: [
          Clip(
            id: 'c1',
            trackId: 't1',
            sourcePath: '/v/a.mp4',
            startMs: 0,
            endMs: 30000,
          ),
        ],
      ),
    ],
    durationMs: 30000,
  );
}

Future<void> _pumpDialog(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: ExportDialog(project: _project())),
      ),
    ),
  );
  await tester.pump();
}

void _deleteFiles(List<String> paths) {
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}

void main() {
  group('ExportDialog', () {
    testWidgets('options state renders format/resolution/quality + Export',
        (WidgetTester tester) async {
      final fake = _FastFfmpeg();
      addTearDown(() => _deleteFiles(fake.createdFiles));
      final container = ProviderContainer(
        overrides: [ffmpegServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await _pumpDialog(tester, container);

      expect(find.text('Export Project'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('Resolution'), findsOneWidget);
      expect(find.text('Quality'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      // Neither progress nor done states are visible yet.
      expect(find.textContaining('Exporting'), findsNothing);
      expect(find.text('Export Complete'), findsNothing);
      expect(container.read(isExportingProvider), isFalse);
    });

    testWidgets('tap Export shows the progress UI and marks exporting',
        (WidgetTester tester) async {
      final fake = _GatedFfmpeg();
      addTearDown(() => _deleteFiles(fake.createdFiles));
      final container = ProviderContainer(
        overrides: [ffmpegServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await _pumpDialog(tester, container);

      await tester.tap(find.text('Export'));
      await tester.pump();
      await tester.pump();

      expect(fake.lastJob, isNotNull);
      expect(find.textContaining('Exporting'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(container.read(isExportingProvider), isTrue);

      // Let the parked run finish so no async work leaks into the next
      // test; the dialog lands on done (covered properly below).
      fake.gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('tap Cancel returns to options and clears isExporting',
        (WidgetTester tester) async {
      final fake = _GatedFfmpeg();
      addTearDown(() => _deleteFiles(fake.createdFiles));
      final container = ProviderContainer(
        overrides: [ffmpegServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await _pumpDialog(tester, container);

      await tester.tap(find.text('Export'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Exporting'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.text('Export'), findsOneWidget);
      expect(find.textContaining('Exporting'), findsNothing);
      expect(find.text('Export Complete'), findsNothing);
      expect(container.read(isExportingProvider), isFalse);

      // The parked run now finishes into the cancelled use case
      // (success false), so the dialog stays on the options state.
      fake.gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Export Complete'), findsNothing);
      expect(container.read(isExportingProvider), isFalse);
    });

    testWidgets('success shows done and records the export result',
        (WidgetTester tester) async {
      final fake = _FastFfmpeg();
      addTearDown(() => _deleteFiles(fake.createdFiles));
      final container = ProviderContainer(
        overrides: [ffmpegServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await _pumpDialog(tester, container);

      await tester.tap(find.text('Export'));
      // Bounded pumps (no pumpAndSettle: the determinate progress UI is
      // brief and the fake has no real async gaps).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Export Complete'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(container.read(isExportingProvider), isFalse);
      final result = container.read(lastExportResultProvider);
      expect(result, isNotNull);
      expect(result!.success, isTrue);
      expect(result.outputPath, endsWith('_export.mp4'));
      expect(File(result.outputPath).existsSync(), isTrue);
    });
  });
}
