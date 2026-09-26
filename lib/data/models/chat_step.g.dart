// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_step.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatStepImpl _$$ChatStepImplFromJson(Map<String, dynamic> json) =>
    _$ChatStepImpl(
      toolCallId: json['toolCallId'] as String,
      toolName: json['toolName'] as String,
      args: json['args'] as Map<String, dynamic>? ?? const {},
      summary: json['summary'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      round: (json['round'] as num?)?.toInt() ?? 0,
      kind:
          $enumDecodeNullable(_$ChatStepKindEnumMap, json['kind']) ??
          ChatStepKind.read,
    );

Map<String, dynamic> _$$ChatStepImplToJson(_$ChatStepImpl instance) =>
    <String, dynamic>{
      'toolCallId': instance.toolCallId,
      'toolName': instance.toolName,
      'args': instance.args,
      'summary': instance.summary,
      'success': instance.success,
      'durationMs': instance.durationMs,
      'round': instance.round,
      'kind': _$ChatStepKindEnumMap[instance.kind]!,
    };

const _$ChatStepKindEnumMap = {
  ChatStepKind.read: 'read',
  ChatStepKind.edit: 'edit',
};
