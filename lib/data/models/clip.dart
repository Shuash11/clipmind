import 'package:freezed_annotation/freezed_annotation.dart';

part 'clip.freezed.dart';
part 'clip.g.dart';

@freezed
class Clip with _$Clip {
  const factory Clip({
    required String id,
    required String trackId,
    required String sourcePath,
    required int startMs,
    required int endMs,
    @Default(0) int positionMs,
    @Default({}) Map<String, dynamic> transformations,
    String? label,
    @Default(false) bool muted,
  }) = _Clip;

  factory Clip.fromJson(Map<String, dynamic> json) => _$ClipFromJson(json);
}
