import 'package:freezed_annotation/freezed_annotation.dart';

part 'edit_operation.freezed.dart';
part 'edit_operation.g.dart';

enum EditOperationType {
  trim,
  cut,
  merge,
  changeSpeed,
  mute,
  overlayText,
  resize,
  rotate,
  extractAudio,
  generateThumbnail,
  changeFormat,
  adjustBrightness,
  changeVolume,
  overlayWatermark,
  burnCaptions,
  addTransition,
  applyEffect,
  // Manual structural ops (append-only: Drift stores enums as int index,
  // so new values go last to keep existing DB rows valid). Local ops —
  // never FFmpeg jobs, never model tools.
  deleteClip,
  copyClip,
  moveClip,
  // Panel-driven sound op (append-only, same Drift rule). UI-driven like
  // the structural ops above — journaled and undoable, but never a model
  // tool (the 20-tool cap holds; `sound_path` is app-generated).
  addSound,
  // Manual trim/split (append-only, same Drift rule). Pure structural ops:
  // the export slices per-clip `startMs`/`endMs` into the shared source,
  // so no FFmpeg and no repointing is needed. Manual-only — never model
  // tools (the 20-tool cap holds).
  trimClip,
  splitClip;

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
