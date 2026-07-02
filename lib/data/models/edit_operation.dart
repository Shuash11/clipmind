import 'package:freezed_annotation/freezed_annotation.dart';

part 'edit_operation.freezed.dart';
part 'edit_operation.g.dart';

enum EditOperationType {
  trim, cut, merge, changeSpeed, mute,
  overlayText, resize, rotate, extractAudio,
  generateThumbnail, changeFormat, adjustBrightness,
  changeVolume, overlayWatermark;

  String get jsonValue => name;
}

enum OperationStatus { pending, applied, failed }

@freezed
class EditOperation with _$EditOperation {
  const factory EditOperation({
    required String id,
    required EditOperationType type,
    @Default([]) List<String> targetClipIds,
    @Default({}) Map<String, dynamic> params,
    required DateTime createdAt,
    @Default('') String sourceChatMessageId,
    @Default(OperationStatus.applied) OperationStatus status,
    String? ffmpegCommand,
  }) = _EditOperation;

  factory EditOperation.fromJson(Map<String, dynamic> json) =>
      _$EditOperationFromJson(json);
}
