import 'dart:async';
import 'dart:io';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/models/edit_operation.dart';

class ExecutionProgress {
  final String jobId;
  final String operationType;
  final double percent;
  final String status;
  final String? message;

  const ExecutionProgress({
    required this.jobId,
    required this.operationType,
    required this.percent,
    required this.status,
    this.message,
  });
}

class ExecutionResult {
  final bool success;
  final String summary;
  final List<String> outputPaths;
  final List<EditOperation> appliedOps;
  final String? errorMessage;

  const ExecutionResult({
    required this.success,
    required this.summary,
    required this.outputPaths,
    required this.appliedOps,
    this.errorMessage,
  });
}

class ExecutionEngine {
  final FfmpegService _ffmpegService;
  final StreamController<ExecutionProgress> _progressCtrl =
      StreamController<ExecutionProgress>.broadcast();

  Stream<ExecutionProgress> get progress => _progressCtrl.stream;

  ExecutionEngine(this._ffmpegService);

  Future<ExecutionResult> execute(
    List<FfmpegJob> jobs,
    String sourcePath, {
    void Function(String tempPath, String finalPath)? onSwap,
  }) async {
    final outputs = <String>[];
    final appliedOps = <EditOperation>[];
    final tempDir = Directory.systemTemp.createTempSync('clipmind_');

    try {
      for (final job in jobs) {
        // Keep the job's own output extension (audio → .mp3/.aac/.wav,
        // thumbnail → .jpg) so the temp file matches the final container.
        final jobExt = job.outputPath.contains('.')
            ? job.outputPath.substring(job.outputPath.lastIndexOf('.'))
            : '.mp4';
        final tempOutPath = '${tempDir.path}/${job.id}_output$jobExt';
        final tempJob = FfmpegJob(
          id: job.id,
          args: job.args,
          expectedDurationMs: job.expectedDurationMs,
          inputPath: job.inputPath,
          outputPath: tempOutPath,
        );

        _progressCtrl.add(ExecutionProgress(
          jobId: job.id,
          operationType: _extractOpType(job),
          percent: 0.0,
          status: 'running',
          message: 'Processing ${_extractOpType(job)}...',
        ));

        final result = await _ffmpegService.runSync(tempJob);

        if (!result.success) {
          return ExecutionResult(
            success: false,
            summary: 'Failed at ${_extractOpType(job)}',
            outputPaths: outputs,
            appliedOps: appliedOps,
            errorMessage: result.stderr ?? 'FFmpeg exited with code ${result.exitCode}',
          );
        }

        _progressCtrl.add(ExecutionProgress(
          jobId: job.id,
          operationType: _extractOpType(job),
          percent: 1.0,
          status: 'complete',
          message: '${_extractOpType(job)} complete',
        ));

        final finalPath = job.outputPath;
        if (tempOutPath != finalPath) {
          await File(tempOutPath).copy(finalPath);
          if (!File(finalPath).existsSync()) {
            return ExecutionResult(
              success: false,
              summary: 'Copy failed for ${_extractOpType(job)}',
              outputPaths: outputs,
              appliedOps: appliedOps,
              errorMessage: 'Failed to copy output to $finalPath',
            );
          }
        }
        outputs.add(finalPath);

        appliedOps.add(EditOperation(
          id: job.id,
          type: _parseOpType(job),
          targetClipIds: [job.id],
          params: {},
          createdAt: DateTime.now(),
          ffmpegCommand: job.args.join(' '),
        ));
      }

      return ExecutionResult(
        success: true,
        summary: 'Applied ${appliedOps.length} operation(s)',
        outputPaths: outputs,
        appliedOps: appliedOps,
      );
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  }

  String _extractOpType(FfmpegJob job) {
    if (job.args.contains('-an')) return 'mute';
    if (job.args.any((a) => a.startsWith('atrim'))) return 'trim';
    if (job.args.any((a) => a.contains('setpts'))) return 'change_speed';
    if (job.args.any((a) => a.startsWith('scale'))) return 'resize';
    if (job.args.any((a) => a.startsWith('transpose'))) return 'rotate';
    if (job.args.any((a) => a.contains('drawtext'))) return 'overlay_text';
    if (job.args.any((a) => a.contains('subtitles'))) return 'burn_captions';
    if (job.args.any((a) => a.contains('xfade='))) return 'add_transition';
    if (job.args.any((a) => a.contains('overlay='))) return 'overlay_watermark';
    if (job.args.any((a) => a.contains('brightness'))) return 'adjust_brightness';
    // After the brightness check so `eq=brightness=` keeps mapping to
    // adjust_brightness.
    if (job.args.any((a) => a.contains('vignette='))) return 'apply_effect';
    if (job.args.any((a) => a.contains('gblur='))) return 'apply_effect';
    if (job.args.any((a) => a.contains('eq=contrast='))) {
      return 'apply_effect';
    }
    if (job.args.any((a) => a.contains('eq=saturation='))) {
      return 'apply_effect';
    }
    // add_sound before the volume check: the amix leg carries its own
    // `volume=` filter, so a volume-first order would mislabel mixed jobs
    // as change_volume. The one-sided form has no amix graph — it is the
    // only other two-input job mapping the sound track (`1:a`); merge and
    // add_transition already returned above via concat/xfade.
    if (job.args.any((a) => a.contains('amix'))) return 'add_sound';
    if (job.args.where((a) => a == '-i').length >= 2 &&
        job.args.contains('1:a')) {
      return 'add_sound';
    }
    if (job.args.any((a) => a.contains('volume='))) return 'change_volume';
    if (job.args.contains('-vn')) return 'extract_audio';
    if (job.args.contains('-vframes')) return 'generate_thumbnail';
    if (job.args.contains('concat=n=')) return 'merge';
    if (job.args.any((a) => a.contains('select'))) return 'cut';
    return 'unknown';
  }

  EditOperationType _parseOpType(FfmpegJob job) {
    switch (_extractOpType(job)) {
      case 'trim': return EditOperationType.trim;
      case 'cut': return EditOperationType.cut;
      case 'merge': return EditOperationType.merge;
      case 'change_speed': return EditOperationType.changeSpeed;
      case 'mute': return EditOperationType.mute;
      case 'overlay_text': return EditOperationType.overlayText;
      case 'resize': return EditOperationType.resize;
      case 'rotate': return EditOperationType.rotate;
      case 'extract_audio': return EditOperationType.extractAudio;
      case 'burn_captions': return EditOperationType.burnCaptions;
      case 'add_transition': return EditOperationType.addTransition;
      case 'apply_effect': return EditOperationType.applyEffect;
      case 'delete_clip': return EditOperationType.deleteClip;
      case 'copy_clip': return EditOperationType.copyClip;
      case 'move_clip': return EditOperationType.moveClip;
      case 'generate_thumbnail': return EditOperationType.generateThumbnail;
      case 'adjust_brightness': return EditOperationType.adjustBrightness;
      case 'add_sound': return EditOperationType.addSound;
      case 'change_volume': return EditOperationType.changeVolume;
      case 'overlay_watermark': return EditOperationType.overlayWatermark;
      default: return EditOperationType.changeFormat;
    }
  }

  void cancel() {
    _ffmpegService.cancel();
  }

  void dispose() {
    _progressCtrl.add(const ExecutionProgress(
      jobId: '',
      operationType: '',
      percent: 0,
      status: 'cancelled',
    ));
    _progressCtrl.close();
  }
}
