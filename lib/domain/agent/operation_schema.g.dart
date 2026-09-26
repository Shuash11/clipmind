// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EditOperationSetImpl _$$EditOperationSetImplFromJson(
  Map<String, dynamic> json,
) => _$EditOperationSetImpl(
  operations: (json['operations'] as List<dynamic>)
      .map((e) => EditOperationRequest.fromJson(e as Map<String, dynamic>))
      .toList(),
  summary: json['summary'] as String,
  clarificationNeeded: json['clarification_needed'] as String?,
);

Map<String, dynamic> _$$EditOperationSetImplToJson(
  _$EditOperationSetImpl instance,
) => <String, dynamic>{
  'operations': instance.operations,
  'summary': instance.summary,
  'clarification_needed': instance.clarificationNeeded,
};

_$EditOperationRequestImpl _$$EditOperationRequestImplFromJson(
  Map<String, dynamic> json,
) => _$EditOperationRequestImpl(
  id: json['id'] as String,
  type: json['type'] as String,
  targetClipId: json['target_clip_id'],
  params: json['params'] as Map<String, dynamic>,
);

Map<String, dynamic> _$$EditOperationRequestImplToJson(
  _$EditOperationRequestImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'target_clip_id': instance.targetClipId,
  'params': instance.params,
};
