// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_turn.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AgentToolCallImpl _$$AgentToolCallImplFromJson(Map<String, dynamic> json) =>
    _$AgentToolCallImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      args: json['args'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$$AgentToolCallImplToJson(_$AgentToolCallImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'args': instance.args,
    };

_$AgentTurnMessageImpl _$$AgentTurnMessageImplFromJson(
  Map<String, dynamic> json,
) => _$AgentTurnMessageImpl(
  role: $enumDecode(_$AgentTurnRoleEnumMap, json['role']),
  content: json['content'] as String?,
  toolCalls:
      (json['toolCalls'] as List<dynamic>?)
          ?.map((e) => AgentToolCall.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  toolCallId: json['toolCallId'] as String?,
  toolError: json['toolError'] as bool? ?? false,
  toolName: json['toolName'] as String?,
);

Map<String, dynamic> _$$AgentTurnMessageImplToJson(
  _$AgentTurnMessageImpl instance,
) => <String, dynamic>{
  'role': _$AgentTurnRoleEnumMap[instance.role]!,
  'content': instance.content,
  'toolCalls': instance.toolCalls,
  'toolCallId': instance.toolCallId,
  'toolError': instance.toolError,
  'toolName': instance.toolName,
};

const _$AgentTurnRoleEnumMap = {
  AgentTurnRole.user: 'user',
  AgentTurnRole.assistant: 'assistant',
  AgentTurnRole.toolResult: 'toolResult',
};

_$AgentTurnRequestImpl _$$AgentTurnRequestImplFromJson(
  Map<String, dynamic> json,
) => _$AgentTurnRequestImpl(
  systemPrompt: json['systemPrompt'] as String,
  userContent: json['userContent'] as String,
  tools:
      (json['tools'] as List<dynamic>?)
          ?.map((e) => ToolDefinition.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  history:
      (json['history'] as List<dynamic>?)
          ?.map((e) => AgentTurnMessage.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 60,
  temperature: (json['temperature'] as num?)?.toDouble() ?? 0.1,
);

Map<String, dynamic> _$$AgentTurnRequestImplToJson(
  _$AgentTurnRequestImpl instance,
) => <String, dynamic>{
  'systemPrompt': instance.systemPrompt,
  'userContent': instance.userContent,
  'tools': instance.tools,
  'history': instance.history,
  'timeoutSeconds': instance.timeoutSeconds,
  'temperature': instance.temperature,
};

_$AgentToolCallRecordImpl _$$AgentToolCallRecordImplFromJson(
  Map<String, dynamic> json,
) => _$AgentToolCallRecordImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  args: json['args'] as Map<String, dynamic>? ?? const {},
  success: json['success'] as bool,
  summary: json['summary'] as String? ?? '',
  durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$AgentToolCallRecordImplToJson(
  _$AgentToolCallRecordImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'args': instance.args,
  'success': instance.success,
  'summary': instance.summary,
  'durationMs': instance.durationMs,
};

_$AgentTurnResultImpl _$$AgentTurnResultImplFromJson(
  Map<String, dynamic> json,
) => _$AgentTurnResultImpl(
  text: json['text'] as String? ?? '',
  toolCalls:
      (json['toolCalls'] as List<dynamic>?)
          ?.map((e) => AgentToolCall.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  records:
      (json['records'] as List<dynamic>?)
          ?.map((e) => AgentToolCallRecord.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  stopReason:
      $enumDecodeNullable(_$AgentTurnStopReasonEnumMap, json['stopReason']) ??
      AgentTurnStopReason.stop,
);

Map<String, dynamic> _$$AgentTurnResultImplToJson(
  _$AgentTurnResultImpl instance,
) => <String, dynamic>{
  'text': instance.text,
  'toolCalls': instance.toolCalls,
  'records': instance.records,
  'stopReason': _$AgentTurnStopReasonEnumMap[instance.stopReason]!,
};

const _$AgentTurnStopReasonEnumMap = {
  AgentTurnStopReason.stop: 'stop',
  AgentTurnStopReason.toolCalls: 'toolCalls',
  AgentTurnStopReason.maxRounds: 'maxRounds',
  AgentTurnStopReason.error: 'error',
};
