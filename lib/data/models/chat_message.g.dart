// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => _ChatMessage(
  id: json['id'] as String,
  role: $enumDecode(_$ChatRoleEnumMap, json['role']),
  content: json['content'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  resultingOperationIds:
      (json['resultingOperationIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  status:
      $enumDecodeNullable(_$MessageStatusEnumMap, json['status']) ??
      MessageStatus.applied,
  steps:
      (json['steps'] as List<dynamic>?)
          ?.map((e) => ChatStep.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ChatMessageToJson(_ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': _$ChatRoleEnumMap[instance.role]!,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
      'resultingOperationIds': instance.resultingOperationIds,
      'status': _$MessageStatusEnumMap[instance.status]!,
      'steps': instance.steps.map((e) => e.toJson()).toList(),
    };

const _$ChatRoleEnumMap = {ChatRole.user: 'user', ChatRole.agent: 'agent'};

const _$MessageStatusEnumMap = {
  MessageStatus.thinking: 'thinking',
  MessageStatus.applied: 'applied',
  MessageStatus.needsClarification: 'needsClarification',
  MessageStatus.error: 'error',
};
