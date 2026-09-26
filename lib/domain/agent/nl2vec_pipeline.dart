import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/ffmpeg/filter_escaping.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'agent_edit_applier.dart';
import 'stage_1_input_validation.dart';
import 'stage_2_prompt_construction.dart';
import 'stage_3_intent_parsing.dart';
import 'stage_4_output_validation.dart';
import 'stage_5_command_mapping.dart';
import 'stage_6_execution.dart';
import 'operation_schema.dart';

enum PipelineStage {
  idle, validating, thinking, applying, ready, error
}

enum SubmitStatus { success, clarificationNeeded, error }

class SubmitResult {
  final SubmitStatus status;
  final String message;
  final List<EditOperation> appliedOperations;
  final String? outputPath;

  const SubmitResult({
    required this.status,
    required this.message,
    this.appliedOperations = const [],
    this.outputPath,
  });
}

class PipelineEvent {
  final PipelineStage stage;
  final String message;
  final double? progress;
  final String? outputPath;
  const PipelineEvent(this.stage, this.message, [this.progress, this.outputPath]);
}

class Nl2VecPipeline {
  final FfmpegService _ffmpegService;
  final StreamController<PipelineEvent> _events = StreamController.broadcast();

  Stream<PipelineEvent> get events => _events.stream;

  Nl2VecPipeline({
    required this._ffmpegService,
  });

  Future<SubmitResult> submitCommand(
    String text,
    Project project, {
    LlmProvider? provider,
    VideoMetadata? metadata,
    List<AgentRequest>? recentHistory,
    AgentEditApplier? applier,
  }) async {
    if (provider == null) {
      const result = SubmitResult(
        status: SubmitStatus.error,
        message: 'No LLM provider configured',
      );
      _events.add(const PipelineEvent(PipelineStage.error, 'No LLM provider configured'));
      return result;
    }

    return _executeWithEvents(() async {
      _events.add(const PipelineEvent(PipelineStage.validating, 'Validating input...'));

      final clipSnapshots = _clipSnapshotsOf(project);
      final (validated, stage1Error) = InputValidator.validate(
        text,
        metadata,
        projectClips: clipSnapshots,
      );
      if (stage1Error != null || validated == null) {
        throw PipelineException(
          'Validation failed: ${stage1Error?.message ?? "Unknown error"}',
        );
      }

      _events.add(const PipelineEvent(PipelineStage.thinking, 'Building prompt...'));

      final schemaJson = _buildSchemaJson();
      final request = PromptConstructor.build(
        validated,
        schemaJson,
        recentHistory: recentHistory,
      );

      _events.add(const PipelineEvent(PipelineStage.thinking, 'Thinking...'));

      final (parsed, parseError) = await IntentParser.parse(provider, request);
      if (parseError != null) {
        throw PipelineException('LLM error: ${parseError.message}');
      }
      if (parsed == null) {
        throw const PipelineException('LLM returned empty response');
      }

      final rawJson = _serializeToJson(parsed);

      _events.add(const PipelineEvent(PipelineStage.validating, 'Validating LLM response...'));

      var (validatedSet, stage4Error, clarification) = OutputValidator.validate(rawJson);

      if (clarification != null) {
        return SubmitResult(
          status: SubmitStatus.clarificationNeeded,
          message: 'Clarification needed: ${clarification.question}',
        );
      }

      if (stage4Error != null) {
        _events.add(const PipelineEvent(PipelineStage.thinking, 'Correcting response...'));
        final retryRequest = AgentRequest(
          systemPrompt: request.systemPrompt,
          userCommand: OutputValidator.buildRetryPrompt(
            validated.text,
            stage4Error.message.split('; '),
          ),
          schemaJson: schemaJson,
          timeoutSeconds: 60,
        );

        final (retryParsed, retryError) = await IntentParser.parse(
          provider, retryRequest,
          isRetry: true,
        );

        if (retryError != null || retryParsed == null) {
          throw PipelineException(
            'Validation failed after retry: ${stage4Error.message}',
          );
        }

        final retryJson = _serializeToJson(retryParsed);
        final (retryValidated, retryStage4Error, retryClarification) =
            OutputValidator.validate(retryJson);

        if (retryClarification != null) {
          return SubmitResult(
            status: SubmitStatus.clarificationNeeded,
            message: 'Clarification needed: ${retryClarification.question}',
          );
        }
        if (retryStage4Error != null || retryValidated == null) {
          throw PipelineException(
            'Validation failed after retry: ${retryStage4Error?.message ?? stage4Error.message}',
          );
        }

        validatedSet = retryValidated;
      }

      _events.add(const PipelineEvent(PipelineStage.applying, 'Generating FFmpeg commands...'));

      final clipPathMap = _buildClipPathMap(project);
      final defaultPath = _resolveDefaultPath(project, clipPathMap);
      if (defaultPath == null) {
        throw const PipelineException('No video file in project');
      }
      final outputDir = project.outputDir;
      final projectDirForValidation =
          outputDir.trim().isNotEmpty ? outputDir : _dirOf(defaultPath);

      final jobs = CommandMapper.mapOperations(
        validatedSet!,
        clipPathMap,
        outputDir,
        defaultPath: defaultPath,
        projectDir: projectDirForValidation,
      );

      _events.add(const PipelineEvent(PipelineStage.applying, 'Executing FFmpeg...'));

      final engine = ExecutionEngine(_ffmpegService);
      final result = await engine.execute(jobs, '');
      engine.dispose();

      if (!result.success) {
        throw PipelineException(
          'FFmpeg execution failed: ${result.errorMessage ?? result.summary}',
        );
      }

      final enriched = _toEditOperations(validatedSet, jobs);
      final outputPath =
          result.outputPaths.isNotEmpty ? result.outputPaths.first : null;

      if (applier != null && enriched.isNotEmpty) {
        final jobOutputById = <String, String>{};
        for (var i = 0; i < jobs.length; i++) {
          final out = i < result.outputPaths.length
              ? result.outputPaths[i]
              : (outputPath ?? jobs[i].outputPath);
          jobOutputById[jobs[i].id] = out;
        }
        for (final op in enriched) {
          final out = jobOutputById[op.id] ?? outputPath;
          if (out != null) {
            await applier.apply(op, out);
          }
        }
      }

      final summary = validatedSet.summary.isNotEmpty
          ? validatedSet.summary
          : result.summary;
      _events.add(PipelineEvent(PipelineStage.ready, summary, null, outputPath));
      return SubmitResult(
        status: SubmitStatus.success,
        message: summary,
        appliedOperations: enriched,
        outputPath: outputPath,
      );
    });
  }

  Future<SubmitResult> _executeWithEvents(
    Future<SubmitResult> Function() fn,
  ) async {
    try {
      final result = await fn();
      if (result.status != SubmitStatus.success) {
        _events.add(PipelineEvent(
          result.status == SubmitStatus.clarificationNeeded
              ? PipelineStage.ready
              : PipelineStage.error,
          result.message,
        ));
      }
      return result;
    } on PipelineException catch (e) {
      _events.add(PipelineEvent(PipelineStage.error, e.message));
      return SubmitResult(status: SubmitStatus.error, message: e.message);
    } on CommandMappingException catch (e) {
      _events.add(PipelineEvent(PipelineStage.error, e.message));
      return SubmitResult(status: SubmitStatus.error, message: e.message);
    } on FilterValidationException catch (e) {
      _events.add(PipelineEvent(PipelineStage.error, e.message));
      return SubmitResult(status: SubmitStatus.error, message: e.message);
    } catch (e) {
      _events.add(PipelineEvent(PipelineStage.error, 'Unexpected error: $e'));
      return SubmitResult(
        status: SubmitStatus.error,
        message: 'Unexpected error: $e',
      );
    }
  }

  List<ClipSnapshot> _clipSnapshotsOf(Project project) {
    final snapshots = <ClipSnapshot>[];
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        snapshots.add(ClipSnapshot(
          id: clip.id,
          trackId: clip.trackId,
          label: clip.label ?? clip.id,
          startMs: clip.startMs,
          endMs: clip.endMs,
          positionMs: clip.positionMs,
        ));
      }
    }
    return snapshots;
  }

  Map<String, String> _buildClipPathMap(Project project) {
    final map = <String, String>{};
    for (final track in project.tracks) {
      for (final clip in track.clips) {
        if (clip.sourcePath.trim().isNotEmpty) {
          map[clip.id] = clip.sourcePath;
        }
      }
    }
    return map;
  }

  String? _resolveDefaultPath(Project project, Map<String, String> clipPathMap) {
    if (project.sourceMediaPaths.isNotEmpty) {
      return project.sourceMediaPaths.first;
    }
    if (clipPathMap.values.isNotEmpty) {
      return clipPathMap.values.first;
    }
    return null;
  }

  String _dirOf(String path) {
    try {
      final parent = File(path).parent.path;
      if (parent.isNotEmpty && parent != '.' && parent != '') return parent;
    } catch (_) {}
    final normalized = path.replaceAll(r'\', '/');
    final idx = normalized.lastIndexOf('/');
    if (idx > 0) return path.substring(0, idx);
    return '.';
  }

  List<EditOperation> _toEditOperations(
    EditOperationSet set,
    List<FfmpegJob> jobs,
  ) {
    final argsById = <String, String>{
      for (final job in jobs) job.id: job.args.join(' '),
    };
    final fallbackArgs = jobs.isNotEmpty ? jobs.first.args.join(' ') : '';
    return set.operations.map((req) {
      return EditOperation(
        id: req.id,
        type: _parseType(req.type),
        targetClipIds: [req.targetClipId?.toString() ?? '_default'],
        params: Map<String, dynamic>.from(req.params),
        createdAt: DateTime.now(),
        status: OperationStatus.applied,
        ffmpegCommand: argsById[req.id] ?? fallbackArgs,
      );
    }).toList();
  }

  EditOperationType _parseType(String type) {
    switch (type) {
      case 'trim':
        return EditOperationType.trim;
      case 'cut':
        return EditOperationType.cut;
      case 'merge':
        return EditOperationType.merge;
      case 'change_speed':
        return EditOperationType.changeSpeed;
      case 'mute':
        return EditOperationType.mute;
      case 'overlay_text':
        return EditOperationType.overlayText;
      case 'resize':
        return EditOperationType.resize;
      case 'rotate':
        return EditOperationType.rotate;
      case 'extract_audio':
        return EditOperationType.extractAudio;
      case 'generate_thumbnail':
        return EditOperationType.generateThumbnail;
      case 'change_format':
        return EditOperationType.changeFormat;
      case 'adjust_brightness':
        return EditOperationType.adjustBrightness;
      case 'change_volume':
        return EditOperationType.changeVolume;
      case 'overlay_watermark':
        return EditOperationType.overlayWatermark;
      default:
        return EditOperationType.changeFormat;
    }
  }

  String _buildSchemaJson() {
    return jsonEncode({
      'operations': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'type': {
              'type': 'string',
              'enum': [
                'trim', 'cut', 'merge', 'change_speed', 'mute',
                'overlay_text', 'resize', 'rotate',
                'extract_audio', 'generate_thumbnail', 'change_format',
                'adjust_brightness', 'change_volume', 'overlay_watermark',
              ],
            },
            'target_clip_id': {'type': 'string'},
            'params': {'type': 'object'},
          },
          'required': ['id', 'type', 'target_clip_id', 'params'],
        },
      },
      'summary': {'type': 'string'},
      'clarification_needed': {'type': 'string'},
    });
  }

  String _serializeToJson(EditOperationSet set) {
    return jsonEncode(set.toJson());
  }

  void dispose() {
    _events.close();
  }
}

class PipelineException implements Exception {
  final String message;
  const PipelineException(this.message);

  @override
  String toString() => message;
}
