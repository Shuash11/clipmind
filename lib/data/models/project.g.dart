// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProjectImpl _$$ProjectImplFromJson(Map<String, dynamic> json) =>
    _$ProjectImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sourceMediaPaths:
          (json['sourceMediaPaths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      tracks:
          (json['tracks'] as List<dynamic>?)
              ?.map((e) => Track.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      thumbnailPath: json['thumbnailPath'] as String?,
      chatHistory:
          (json['chatHistory'] as List<dynamic>?)
              ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      editHistory:
          (json['editHistory'] as List<dynamic>?)
              ?.map((e) => EditOperation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      outputDir: json['outputDir'] as String? ?? '',
    );

Map<String, dynamic> _$$ProjectImplToJson(_$ProjectImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'sourceMediaPaths': instance.sourceMediaPaths,
      'tracks': instance.tracks,
      'durationMs': instance.durationMs,
      'thumbnailPath': instance.thumbnailPath,
      'chatHistory': instance.chatHistory,
      'editHistory': instance.editHistory,
      'outputDir': instance.outputDir,
    };
