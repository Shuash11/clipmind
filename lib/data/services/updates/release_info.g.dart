// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'release_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReleaseInfoImpl _$$ReleaseInfoImplFromJson(Map<String, dynamic> json) =>
    _$ReleaseInfoImpl(
      tagName: json['tagName'] as String,
      major: (json['major'] as num).toInt(),
      minor: (json['minor'] as num).toInt(),
      patch: (json['patch'] as num).toInt(),
      releaseNotes: json['releaseNotes'] as String,
      downloadUrl: json['downloadUrl'] as String,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
    );

Map<String, dynamic> _$$ReleaseInfoImplToJson(_$ReleaseInfoImpl instance) =>
    <String, dynamic>{
      'tagName': instance.tagName,
      'major': instance.major,
      'minor': instance.minor,
      'patch': instance.patch,
      'releaseNotes': instance.releaseNotes,
      'downloadUrl': instance.downloadUrl,
      'publishedAt': instance.publishedAt.toIso8601String(),
    };
