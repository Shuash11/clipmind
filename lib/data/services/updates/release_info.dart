import 'package:freezed_annotation/freezed_annotation.dart';

part 'release_info.freezed.dart';
part 'release_info.g.dart';

@freezed
class ReleaseInfo with _$ReleaseInfo {
  const factory ReleaseInfo({
    required String tagName,
    required int major,
    required int minor,
    required int patch,
    required String releaseNotes,
    required String downloadUrl,
    required DateTime publishedAt,
  }) = _ReleaseInfo;

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) => _$ReleaseInfoFromJson(json);
}
