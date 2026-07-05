// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'release_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ReleaseInfo _$ReleaseInfoFromJson(Map<String, dynamic> json) {
  return _ReleaseInfo.fromJson(json);
}

/// @nodoc
mixin _$ReleaseInfo {
  String get tagName => throw _privateConstructorUsedError;
  int get major => throw _privateConstructorUsedError;
  int get minor => throw _privateConstructorUsedError;
  int get patch => throw _privateConstructorUsedError;
  String get releaseNotes => throw _privateConstructorUsedError;
  String get downloadUrl => throw _privateConstructorUsedError;
  DateTime get publishedAt => throw _privateConstructorUsedError;

  /// Serializes this ReleaseInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReleaseInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReleaseInfoCopyWith<ReleaseInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReleaseInfoCopyWith<$Res> {
  factory $ReleaseInfoCopyWith(
    ReleaseInfo value,
    $Res Function(ReleaseInfo) then,
  ) = _$ReleaseInfoCopyWithImpl<$Res, ReleaseInfo>;
  @useResult
  $Res call({
    String tagName,
    int major,
    int minor,
    int patch,
    String releaseNotes,
    String downloadUrl,
    DateTime publishedAt,
  });
}

/// @nodoc
class _$ReleaseInfoCopyWithImpl<$Res, $Val extends ReleaseInfo>
    implements $ReleaseInfoCopyWith<$Res> {
  _$ReleaseInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReleaseInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tagName = null,
    Object? major = null,
    Object? minor = null,
    Object? patch = null,
    Object? releaseNotes = null,
    Object? downloadUrl = null,
    Object? publishedAt = null,
  }) {
    return _then(
      _value.copyWith(
            tagName: null == tagName
                ? _value.tagName
                : tagName // ignore: cast_nullable_to_non_nullable
                      as String,
            major: null == major
                ? _value.major
                : major // ignore: cast_nullable_to_non_nullable
                      as int,
            minor: null == minor
                ? _value.minor
                : minor // ignore: cast_nullable_to_non_nullable
                      as int,
            patch: null == patch
                ? _value.patch
                : patch // ignore: cast_nullable_to_non_nullable
                      as int,
            releaseNotes: null == releaseNotes
                ? _value.releaseNotes
                : releaseNotes // ignore: cast_nullable_to_non_nullable
                      as String,
            downloadUrl: null == downloadUrl
                ? _value.downloadUrl
                : downloadUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            publishedAt: null == publishedAt
                ? _value.publishedAt
                : publishedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReleaseInfoImplCopyWith<$Res>
    implements $ReleaseInfoCopyWith<$Res> {
  factory _$$ReleaseInfoImplCopyWith(
    _$ReleaseInfoImpl value,
    $Res Function(_$ReleaseInfoImpl) then,
  ) = __$$ReleaseInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String tagName,
    int major,
    int minor,
    int patch,
    String releaseNotes,
    String downloadUrl,
    DateTime publishedAt,
  });
}

/// @nodoc
class __$$ReleaseInfoImplCopyWithImpl<$Res>
    extends _$ReleaseInfoCopyWithImpl<$Res, _$ReleaseInfoImpl>
    implements _$$ReleaseInfoImplCopyWith<$Res> {
  __$$ReleaseInfoImplCopyWithImpl(
    _$ReleaseInfoImpl _value,
    $Res Function(_$ReleaseInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReleaseInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tagName = null,
    Object? major = null,
    Object? minor = null,
    Object? patch = null,
    Object? releaseNotes = null,
    Object? downloadUrl = null,
    Object? publishedAt = null,
  }) {
    return _then(
      _$ReleaseInfoImpl(
        tagName: null == tagName
            ? _value.tagName
            : tagName // ignore: cast_nullable_to_non_nullable
                  as String,
        major: null == major
            ? _value.major
            : major // ignore: cast_nullable_to_non_nullable
                  as int,
        minor: null == minor
            ? _value.minor
            : minor // ignore: cast_nullable_to_non_nullable
                  as int,
        patch: null == patch
            ? _value.patch
            : patch // ignore: cast_nullable_to_non_nullable
                  as int,
        releaseNotes: null == releaseNotes
            ? _value.releaseNotes
            : releaseNotes // ignore: cast_nullable_to_non_nullable
                  as String,
        downloadUrl: null == downloadUrl
            ? _value.downloadUrl
            : downloadUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        publishedAt: null == publishedAt
            ? _value.publishedAt
            : publishedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReleaseInfoImpl implements _ReleaseInfo {
  const _$ReleaseInfoImpl({
    required this.tagName,
    required this.major,
    required this.minor,
    required this.patch,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.publishedAt,
  });

  factory _$ReleaseInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReleaseInfoImplFromJson(json);

  @override
  final String tagName;
  @override
  final int major;
  @override
  final int minor;
  @override
  final int patch;
  @override
  final String releaseNotes;
  @override
  final String downloadUrl;
  @override
  final DateTime publishedAt;

  @override
  String toString() {
    return 'ReleaseInfo(tagName: $tagName, major: $major, minor: $minor, patch: $patch, releaseNotes: $releaseNotes, downloadUrl: $downloadUrl, publishedAt: $publishedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReleaseInfoImpl &&
            (identical(other.tagName, tagName) || other.tagName == tagName) &&
            (identical(other.major, major) || other.major == major) &&
            (identical(other.minor, minor) || other.minor == minor) &&
            (identical(other.patch, patch) || other.patch == patch) &&
            (identical(other.releaseNotes, releaseNotes) ||
                other.releaseNotes == releaseNotes) &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    tagName,
    major,
    minor,
    patch,
    releaseNotes,
    downloadUrl,
    publishedAt,
  );

  /// Create a copy of ReleaseInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReleaseInfoImplCopyWith<_$ReleaseInfoImpl> get copyWith =>
      __$$ReleaseInfoImplCopyWithImpl<_$ReleaseInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReleaseInfoImplToJson(this);
  }
}

abstract class _ReleaseInfo implements ReleaseInfo {
  const factory _ReleaseInfo({
    required final String tagName,
    required final int major,
    required final int minor,
    required final int patch,
    required final String releaseNotes,
    required final String downloadUrl,
    required final DateTime publishedAt,
  }) = _$ReleaseInfoImpl;

  factory _ReleaseInfo.fromJson(Map<String, dynamic> json) =
      _$ReleaseInfoImpl.fromJson;

  @override
  String get tagName;
  @override
  int get major;
  @override
  int get minor;
  @override
  int get patch;
  @override
  String get releaseNotes;
  @override
  String get downloadUrl;
  @override
  DateTime get publishedAt;

  /// Create a copy of ReleaseInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReleaseInfoImplCopyWith<_$ReleaseInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
