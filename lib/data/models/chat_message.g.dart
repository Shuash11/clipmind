// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMessageImpl _$$ChatMessageImplFromJson(Map<String, dynamic> json) =>
    _$ChatMessageImpl(
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
    );

Map<String, dynamic> _$$ChatMessageImplToJson(_$ChatMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': _$ChatRoleEnumMap[instance.role]!,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
      'resultingOperationIds': instance.resultingOperationIds,
      'status': _$MessageStatusEnumMap[instance.status]!,
    };

const _$ChatRoleEnumMap = {ChatRole.user: 'user', ChatRole.agent: 'agent'};

const _$MessageStatusEnumMap = {
  MessageStatus.thinking: 'thinking',
  MessageStatus.applied: 'applied',
  MessageStatus.needsClarification: 'needsClarification',
  MessageStatus.error: 'error',
};
