// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ClipImpl _$$ClipImplFromJson(Map<String, dynamic> json) => _$ClipImpl(
  id: json['id'] as String,
  trackId: json['trackId'] as String,
  sourcePath: json['sourcePath'] as String,
  startMs: (json['startMs'] as num).toInt(),
  endMs: (json['endMs'] as num).toInt(),
  positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
  transformations: json['transformations'] as Map<String, dynamic>? ?? const {},
  label: json['label'] as String?,
  muted: json['muted'] as bool? ?? false,
);

Map<String, dynamic> _$$ClipImplToJson(_$ClipImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'trackId': instance.trackId,
      'sourcePath': instance.sourcePath,
      'startMs': instance.startMs,
      'endMs': instance.endMs,
      'positionMs': instance.positionMs,
      'transformations': instance.transformations,
      'label': instance.label,
      'muted': instance.muted,
    };
