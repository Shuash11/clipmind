import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_step.freezed.dart';
part 'chat_step.g.dart';

/// Read tools answer from ground truth; edit tools run FFmpeg.
enum ChatStepKind { read, edit }

/// One persisted tool-call trace entry on a [ChatMessage].
///
/// Mirrors [AgentToolCallRecord] (domain) in a persistence-friendly shape.
/// Bounded: a run keeps at most 20 steps (see DB layer truncation).
@freezed
class ChatStep with _$ChatStep {
  const factory ChatStep({
    required String toolCallId,
    required String toolName,
    @Default({}) Map<String, dynamic> args,
    @Default('') String summary,
    @Default(false) bool success,
    @Default(0) int durationMs,
    @Default(0) int round,
    @Default(ChatStepKind.read) ChatStepKind kind,
  }) = _ChatStep;

  factory ChatStep.fromJson(Map<String, dynamic> json) =>
      _$ChatStepFromJson(json);
}
