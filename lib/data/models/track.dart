import 'package:freezed_annotation/freezed_annotation.dart';
import 'clip.dart';

part 'track.freezed.dart';
part 'track.g.dart';

enum TrackType { video, audio, text, fx }

@freezed
class Track with _$Track {
  const factory Track({
    required String id,
    required TrackType type,
    @Default([]) List<Clip> clips,
    @Default('') String label,
  }) = _Track;

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);
}
