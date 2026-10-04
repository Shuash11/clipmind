import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
import 'package:clipmind/data/services/ffmpeg/ffprobe_service.dart';
import 'package:clipmind/data/services/ffmpeg/filter_escaping.dart';
import 'package:clipmind/data/services/transcription/whisper_service.dart';
import 'package:clipmind/data/models/project.dart';
import 'package:clipmind/data/models/edit_operation.dart';
import 'agent_activity.dart';
import 'agent_confirmation.dart';
import 'agent_edit_applier.dart';
import 'agent_turn.dart';
import 'stage_1_input_validation.dart';
import 'stage_2_prompt_construction.dart';
import 'stage_3_intent_parsing.dart';
import 'stage_4_output_validation.dart';
import 'stage_5_command_mapping.dart';
import 'stage_6_execution.dart';
import 'operation_schema.dart';
import 'tool_calling_agent.dart';
import 'tools/tool_definition.dart';
import 'tools/tool_executors.dart';

enum PipelineStage {
  idle, validating, thinking, applying, ready, error
}

enum SubmitStatus { success, clarificationNeeded, error, cancelled }

class SubmitResult {
  final SubmitStatus status;
  final String message;
  final List<EditOperation> appliedOperations;
  final String? outputPath;

  /// Full tool-call trace (read + edit + skipped calls) for step rendering.
  final List<AgentToolCallRecord> records;

  const SubmitResult({
    required this.status,
    required this.message,
    this.appliedOperations = const [],
    this.outputPath,
    this.records = const [],
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
  final FfmpegService ffmpegService;
  final FfprobeService ffprobeService;
  final StreamController<PipelineEvent> _events = StreamController.broadcast();

  Stream<PipelineEvent> get events => _events.stream;

  /// Broadcast agent activity for the visible pipeline (Phase-4 seed).
  /// The legacy one-shot path emits nothing here.
  final StreamController<AgentActivityEvent> _agentActivity =
      StreamController<AgentActivityEvent>.broadcast();

  Stream<AgentActivityEvent> get agentActivity => _agentActivity.stream;

  Nl2VecPipeline({
    required this.ffmpegService,
    FfprobeService? ffprobeService,
  }) : ffprobeService = ffprobeService ?? FfprobeService();

  Future<SubmitResult> submitCommand(
    String text,
    Project project, {
    LlmProvider? provider,
    VideoMetadata? metadata,
    List<AgentRequest>? recentHistory,
    AgentEditApplier? applier,
    Project Function()? liveProject,
    CancellationToken? cancellation,
    ConfirmationGate? gate,
    bool dryRun = false,
    // Tool-context wiring (all optional, default null = graceful
    // degradation in the executors). The domain never imports the state
    // layer — the state layer (AgentRunController.submit) must pass these:
    //   readAnalysis / writeAnalysis: `agentAnalysisPortProvider(projectId)`
    //     port's `read` / `write` (AgentAnalysisPort: sync read(kind) /
    //     write(kind, payload); family keyed by projectId).
    //   whisperConfig: `() => WhisperPaths(
    //     binaryPath: settings.whisperBinaryPath,
    //     modelPath: settings.whisperModelPath)` where `settings` is
    //     `ref.read(settingsProvider).value` (empty strings = unset).
    //   resolveFont: `ref.read(resolveFontProvider)` (wired to
    //     FontResolver via fontResolverProvider).
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
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

      // Capability gate (D2): tool-capable providers run the agentic
      // loop; everyone else keeps the legacy one-shot stage path.
      if (provider.supportsToolCalling) {
        return _runToolPath(
          project: project,
          provider: provider,
          validated: validated,
          recentHistory: recentHistory,
          applier: applier,
          liveProject: liveProject,
          cancellation: cancellation,
          gate: gate,
          dryRun: dryRun,
          readAnalysis: readAnalysis,
          writeAnalysis: writeAnalysis,
          whisperConfig: whisperConfig,
          resolveFont: resolveFont,
        );
      }
      if (dryRun) {
        throw const PipelineException(
          'Plan preview needs a tool-capable provider.',
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

      // Caller-probed audio presence for the composed path (the
      // transition-path probe convention): caller metadata wins; a probe
      // failure degrades to null → the legacy `-map 0:a` fallback.
      bool? sourceHasAudio = metadata?.hasAudio;
      if (sourceHasAudio == null) {
        try {
          sourceHasAudio =
              (await ffprobeService.extractMetadata(defaultPath))?.hasAudio;
        } catch (_) {
          sourceHasAudio = null;
        }
      }

      final jobs = CommandMapper.mapOperations(
        validatedSet!,
        clipPathMap,
        outputDir,
        defaultPath: defaultPath,
        projectDir: projectDirForValidation,
        sourceHasAudio: sourceHasAudio,
      );

      _events.add(const PipelineEvent(PipelineStage.applying, 'Executing FFmpeg...'));

      final engine = ExecutionEngine(ffmpegService);
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

  /// Agentic path: the model drives edits through tools (D1/D6).
  ///
  /// Reads live project state per tool call via [liveProject] (falling back
  /// to the static [project]) so the agent edits against live ground truth.
  /// Deterministic plan replay (Phase 6d): executes recorded edit-tool
  /// calls straight through the registry with a real context — no new LLM
  /// call. Non-edit names are skipped with a failure record. The controller
  /// maps [SubmitResult.appliedOperations] to the reply's
  /// `resultingOperationIds`.
  Future<SubmitResult> executePlanned(
    List<ToolCall> planned,
    Project project, {
    AgentEditApplier? applier,
    Project Function()? liveProject,
    CancellationToken? cancellation,
    // Same tool-context wiring as [submitCommand] (see its doc comment
    // for the state-side sources). Replay only runs edit tools, so
    // `resolveFont` is the one that matters here (`overlay_text` `font`
    // arg); the rest are threaded for symmetry.
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) {
    return _executeWithEvents(() async {
      _events.add(
        const PipelineEvent(PipelineStage.applying, 'Applying planned edits...'),
      );
      final ctx = _toolContext(
        project: project,
        applier: applier,
        liveProject: liveProject,
        cancellation: cancellation,
        dryRun: false,
        readAnalysis: readAnalysis,
        writeAnalysis: writeAnalysis,
        whisperConfig: whisperConfig,
        resolveFont: resolveFont,
      );
      final registry = createToolRegistry(ctx);
      final records = <AgentToolCallRecord>[];
      for (final call in planned) {
        if (cancellation?.isCancelled == true) {
          return SubmitResult(
            status: SubmitStatus.cancelled,
            message: 'Cancelled — ${ctx.appliedOperations.length} edit(s) applied.',
            appliedOperations: List.of(ctx.appliedOperations),
            outputPath: ctx.outputPaths.isEmpty
                ? null
                : ctx.outputPaths.first,
            records: List.unmodifiable(records),
          );
        }
        final def = registry.definitionFor(call.name);
        if (def == null || def.category != ToolCategory.edit) {
          records.add(AgentToolCallRecord(
            id: call.id,
            name: call.name,
            args: call.args,
            success: false,
            summary: 'Skipped in replay: "${call.name}" is not an edit tool.',
          ));
          continue;
        }
        final stopwatch = Stopwatch()..start();
        final result = await registry.executorFor(call.name)!.execute(call);
        stopwatch.stop();
        records.add(AgentToolCallRecord(
          id: call.id,
          name: call.name,
          args: call.args,
          success: result.success,
          summary: result.summary,
          durationMs: stopwatch.elapsedMilliseconds,
        ));
        if (!result.success) {
          return SubmitResult(
            status: SubmitStatus.error,
            message: result.error.isNotEmpty
                ? result.error
                : result.summary,
            appliedOperations: List.of(ctx.appliedOperations),
            outputPath: ctx.outputPaths.isEmpty
                ? null
                : ctx.outputPaths.first,
            records: List.unmodifiable(records),
          );
        }
      }
      final applied = List<EditOperation>.from(ctx.appliedOperations);
      final outputPath =
          ctx.outputPaths.isEmpty ? null : ctx.outputPaths.first;
      final message = applied.isEmpty
          ? 'Plan applied: no edits were needed.'
          : 'Plan applied: ${applied.length} edit(s).';
      _events.add(PipelineEvent(PipelineStage.ready, message, null, outputPath));
      return SubmitResult(
        status: SubmitStatus.success,
        message: message,
        appliedOperations: applied,
        outputPath: outputPath,
        records: List.unmodifiable(records),
      );
    });
  }

  /// Shared live-ground-truth context for the tool path and plan replay.
  ///
  /// In dry-run (plan-preview) mode the agent loop still reads the real
  /// project, but edit tools return `{'planned': true, ...}` instead of
  /// executing — every successful edit-tool record is then a planned call
  /// the controller can replay via [executePlanned].
  ToolExecutionContext _toolContext({
    required Project project,
    required AgentEditApplier? applier,
    required Project Function()? liveProject,
    required CancellationToken? cancellation,
    required bool dryRun,
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) {
    final Project Function() readLive = liveProject ?? () => project;
    final clipPathMap = _buildClipPathMap(project);
    final defaultPath = _resolveDefaultPath(project, clipPathMap);
    if (defaultPath == null) {
      throw const PipelineException('No video file in project');
    }
    final outputDir = project.outputDir;
    return ToolExecutionContext(
      project: readLive,
      outputDir: outputDir,
      projectDir:
          outputDir.trim().isNotEmpty ? outputDir : _dirOf(defaultPath),
      applier: applier ??
          AgentEditApplier(
              onApply: (_, _, {removeClipIds = const []}) async {}),
      ffmpegService: ffmpegService,
      ffprobeService: ffprobeService,
      cancellation: cancellation,
      dryRun: dryRun,
      readAnalysis: readAnalysis,
      writeAnalysis: writeAnalysis,
      whisperConfig: whisperConfig,
      resolveFont: resolveFont,
    );
  }

  Future<SubmitResult> _runToolPath({
    required Project project,
    required LlmProvider provider,
    required ValidatedCommand validated,
    required List<AgentRequest>? recentHistory,
    required AgentEditApplier? applier,
    required Project Function()? liveProject,
    required CancellationToken? cancellation,
    required ConfirmationGate? gate,
    bool dryRun = false,
    Map<String, dynamic>? Function(String kind)? readAnalysis,
    void Function(String kind, Map<String, dynamic> payload)? writeAnalysis,
    WhisperPaths? Function()? whisperConfig,
    Future<String?> Function(String familyId)? resolveFont,
  }) async {
    _events.add(const PipelineEvent(PipelineStage.thinking, 'Planning with tools...'));

    final ctx = _toolContext(
      project: project,
      applier: applier,
      liveProject: liveProject,
      cancellation: cancellation,
      dryRun: dryRun,
      readAnalysis: readAnalysis,
      writeAnalysis: writeAnalysis,
      whisperConfig: whisperConfig,
      resolveFont: resolveFont,
    );
    final agent = ToolCallingAgent(provider: provider, context: ctx);
    final forward = agent.activityEvents.listen(_agentActivity.add);
    try {
      final run = await agent.run(
        validated: validated,
        recentHistory: recentHistory,
        cancellation: cancellation,
        gate: gate,
      );
      if (run.status == AgentRunStatus.error) {
        return SubmitResult(
          status: SubmitStatus.error,
          message: run.message,
          records: run.records,
        );
      }
      if (run.status == AgentRunStatus.cancelled) {
        _events.add(PipelineEvent(PipelineStage.ready, run.message));
        return SubmitResult(
          status: SubmitStatus.cancelled,
          message: run.message,
          appliedOperations: run.appliedOperations,
          outputPath: run.outputPath,
          records: run.records,
        );
      }
      _events.add(
        PipelineEvent(PipelineStage.ready, run.message, null, run.outputPath),
      );
      return SubmitResult(
        status: SubmitStatus.success,
        message: run.message,
        appliedOperations: run.appliedOperations,
        outputPath: run.outputPath,
        records: run.records,
      );
    } finally {
      await forward.cancel();
      agent.dispose();
    }
  }

  Future<SubmitResult> _executeWithEvents(
    Future<SubmitResult> Function() fn,
  ) async {
    try {
      final result = await fn();
      if (result.status != SubmitStatus.success) {
        _events.add(PipelineEvent(
          result.status == SubmitStatus.clarificationNeeded ||
                  result.status == SubmitStatus.cancelled
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
      case 'apply_effect':
        return EditOperationType.applyEffect;
      case 'add_transition':
        return EditOperationType.addTransition;
      case 'burn_captions':
        return EditOperationType.burnCaptions;
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
                // burn_captions is agentic-only: the legacy one-shot path
                // has no timed-transcript context and can never
                // meaningfully produce it.
                'add_transition', 'apply_effect',
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
    _agentActivity.close();
  }
}

class PipelineException implements Exception {
  final String message;
  const PipelineException(this.message);

  @override
  String toString() => message;
}


