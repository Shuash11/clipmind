// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EditOperationSet _$EditOperationSetFromJson(Map<String, dynamic> json) =>
    _EditOperationSet(
      operations: (json['operations'] as List<dynamic>)
          .map((e) => EditOperationRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String,
      clarificationNeeded: json['clarification_needed'] as String?,
    );

Map<String, dynamic> _$EditOperationSetToJson(_EditOperationSet instance) =>
    <String, dynamic>{
      'operations': instance.operations,
      'summary': instance.summary,
      'clarification_needed': instance.clarificationNeeded,
    };

_EditOperationRequest _$EditOperationRequestFromJson(
  Map<String, dynamic> json,
) => _EditOperationRequest(
  id: json['id'] as String,
  type: json['type'] as String,
  targetClipId: json['target_clip_id'],
  params: json['params'] as Map<String, dynamic>,
);

Map<String, dynamic> _$EditOperationRequestToJson(
  _EditOperationRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'target_clip_id': instance.targetClipId,
  'params': instance.params,
};
