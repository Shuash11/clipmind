import 'dart:async';
import 'dart:convert';
import 'package:clipmind/data/services/llm/llm_provider.dart';
import 'package:clipmind/data/services/ffmpeg/ffmpeg_service.dart';
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

class PipelineEvent {
  final PipelineStage stage;
  final String message;
  final double? progress;
  const PipelineEvent(this.stage, this.message, [this.progress]);
}

class Nl2VecPipeline {
  final FfmpegService _ffmpegService;
  final StreamController<PipelineEvent> _events = StreamController.broadcast();

  Stream<PipelineEvent> get events => _events.stream;

  Nl2VecPipeline({
    required this._ffmpegService,
  });

  Future<String> submitCommand(String text, ProjectSnapshot project, {LlmProvider? provider}) async {
    if (provider == null) {
      _events.add(const PipelineEvent(PipelineStage.error, 'No LLM provider configured'));
      return 'Error: No LLM provider configured';
    }

    return _executeWithEvents(() async {
      _events.add(const PipelineEvent(PipelineStage.validating, 'Validating input...'));

      final (validated, stage1Error) = InputValidator.validate(
        text,
        null,
        projectClips: project.clips,
      );
      if (stage1Error != null || validated == null) {
        throw PipelineException(
          'Validation failed: ${stage1Error?.message ?? "Unknown error"}',
        );
      }

      _events.add(const PipelineEvent(PipelineStage.thinking, 'Building prompt...'));

      final schemaJson = _buildSchemaJson();
      final request = PromptConstructor.build(validated, schemaJson);

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
        return 'Clarification needed: ${clarification.question}';
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
          return 'Clarification needed: ${retryClarification.question}';
        }
        if (retryStage4Error != null || retryValidated == null) {
          throw PipelineException(
            'Validation failed after retry: ${retryStage4Error?.message ?? stage4Error.message}',
          );
        }

        validatedSet = retryValidated;
      }

      _events.add(const PipelineEvent(PipelineStage.applying, 'Generating FFmpeg commands...'));

      final inputPath = _resolveInputPath(project);
      if (inputPath == null) {
        throw const PipelineException('No video clips in project to process');
      }

      final jobs = CommandMapper.mapOperations(validatedSet!, inputPath);

      _events.add(const PipelineEvent(PipelineStage.applying, 'Executing FFmpeg...'));

      final engine = ExecutionEngine(_ffmpegService);
      final result = await engine.execute(jobs, '');
      engine.dispose();

      if (!result.success) {
        throw PipelineException(
          'FFmpeg execution failed: ${result.errorMessage ?? result.summary}',
        );
      }

      return result.summary;
    });
  }

  Future<String> _executeWithEvents(Future<String> Function() fn) async {
    try {
      final result = await fn();
      _events.add(PipelineEvent(PipelineStage.ready, result));
      return result;
    } on PipelineException catch (e) {
      _events.add(PipelineEvent(PipelineStage.error, e.message));
      return 'Error: ${e.message}';
    } catch (e) {
      _events.add(PipelineEvent(PipelineStage.error, 'Unexpected error: $e'));
      return 'Unexpected error: $e';
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
                'overlay_text', 'resize', 'rotate', 'extract_audio',
                'generate_thumbnail', 'change_format', 'adjust_brightness',
                'change_volume', 'overlay_watermark',
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

  String? _resolveInputPath(ProjectSnapshot project) {
    if (project.clips.isNotEmpty) {
      return project.clips.first.id;
    }
    return null;
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
