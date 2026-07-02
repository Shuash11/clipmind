// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_operation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EditOperationImpl _$$EditOperationImplFromJson(Map<String, dynamic> json) =>
    _$EditOperationImpl(
      id: json['id'] as String,
      type: $enumDecode(_$EditOperationTypeEnumMap, json['type']),
      targetClipIds:
          (json['targetClipIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      params: json['params'] as Map<String, dynamic>? ?? const {},
      createdAt: DateTime.parse(json['createdAt'] as String),
      sourceChatMessageId: json['sourceChatMessageId'] as String? ?? '',
      status:
          $enumDecodeNullable(_$OperationStatusEnumMap, json['status']) ??
          OperationStatus.applied,
      ffmpegCommand: json['ffmpegCommand'] as String?,
    );

Map<String, dynamic> _$$EditOperationImplToJson(_$EditOperationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$EditOperationTypeEnumMap[instance.type]!,
      'targetClipIds': instance.targetClipIds,
      'params': instance.params,
      'createdAt': instance.createdAt.toIso8601String(),
      'sourceChatMessageId': instance.sourceChatMessageId,
      'status': _$OperationStatusEnumMap[instance.status]!,
      'ffmpegCommand': instance.ffmpegCommand,
    };

const _$EditOperationTypeEnumMap = {
  EditOperationType.trim: 'trim',
  EditOperationType.cut: 'cut',
  EditOperationType.merge: 'merge',
  EditOperationType.changeSpeed: 'changeSpeed',
  EditOperationType.mute: 'mute',
  EditOperationType.overlayText: 'overlayText',
  EditOperationType.resize: 'resize',
  EditOperationType.rotate: 'rotate',
  EditOperationType.extractAudio: 'extractAudio',
  EditOperationType.generateThumbnail: 'generateThumbnail',
  EditOperationType.changeFormat: 'changeFormat',
  EditOperationType.adjustBrightness: 'adjustBrightness',
  EditOperationType.changeVolume: 'changeVolume',
  EditOperationType.overlayWatermark: 'overlayWatermark',
};

const _$OperationStatusEnumMap = {
  OperationStatus.pending: 'pending',
  OperationStatus.applied: 'applied',
  OperationStatus.failed: 'failed',
};
