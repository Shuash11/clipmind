// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Track _$TrackFromJson(Map<String, dynamic> json) => _Track(
  id: json['id'] as String,
  type: $enumDecode(_$TrackTypeEnumMap, json['type']),
  clips:
      (json['clips'] as List<dynamic>?)
          ?.map((e) => Clip.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  label: json['label'] as String? ?? '',
);

Map<String, dynamic> _$TrackToJson(_Track instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$TrackTypeEnumMap[instance.type]!,
  'clips': instance.clips,
  'label': instance.label,
};

const _$TrackTypeEnumMap = {
  TrackType.video: 'video',
  TrackType.audio: 'audio',
  TrackType.text: 'text',
  TrackType.fx: 'fx',
};
