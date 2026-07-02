import 'package:freezed_annotation/freezed_annotation.dart';

part 'operation_schema.freezed.dart';
part 'operation_schema.g.dart';

@freezed
class EditOperationSet with _$EditOperationSet {
  const factory EditOperationSet({
    required List<EditOperationRequest> operations,
    required String summary,
    String? clarificationNeeded,
  }) = _EditOperationSet;

  factory EditOperationSet.fromJson(Map<String, dynamic> json) =>
      _$EditOperationSetFromJson(json);
}

@freezed
class EditOperationRequest with _$EditOperationRequest {
  const factory EditOperationRequest({
    required String id,
    required String type,
    required dynamic targetClipId,
    required Map<String, dynamic> params,
  }) = _EditOperationRequest;

  factory EditOperationRequest.fromJson(Map<String, dynamic> json) =>
      _$EditOperationRequestFromJson(json);
}

@freezed
class ValidatedCommand with _$ValidatedCommand {
  const factory ValidatedCommand({
    required String text,
    required Map<String, int> normalizedTimecodes,
    required ProjectSnapshot projectSnapshot,
  }) = _ValidatedCommand;
}

@freezed
class ProjectSnapshot with _$ProjectSnapshot {
  const factory ProjectSnapshot({
    required int durationMs,
    required int width,
    required int height,
    required double fps,
    required String codec,
    required bool hasAudio,
    required List<ClipSnapshot> clips,
  }) = _ProjectSnapshot;
}

@freezed
class ClipSnapshot with _$ClipSnapshot {
  const factory ClipSnapshot({
    required String id,
    required String trackId,
    required String label,
    required int startMs,
    required int endMs,
    required int positionMs,
  }) = _ClipSnapshot;
}

@freezed
class AgentRequest with _$AgentRequest {
  const factory AgentRequest({
    required String systemPrompt,
    required String userCommand,
    required String schemaJson,
    required int timeoutSeconds,
  }) = _AgentRequest;
}

@freezed
class ClarificationNeeded with _$ClarificationNeeded {
  const factory ClarificationNeeded({
    required String question,
    required List<String> options,
  }) = _ClarificationNeeded;
}
