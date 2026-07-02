import 'package:freezed_annotation/freezed_annotation.dart';
import 'track.dart';
import 'chat_message.dart';
import 'edit_operation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

@freezed
class Project with _$Project {
  const factory Project({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default([]) List<String> sourceMediaPaths,
    @Default([]) List<Track> tracks,
    @Default(0) int durationMs,
    String? thumbnailPath,
    @Default([]) List<ChatMessage> chatHistory,
    @Default([]) List<EditOperation> editHistory,
    @Default('') String outputDir,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);
}
