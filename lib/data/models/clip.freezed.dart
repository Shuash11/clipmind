// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Clip _$ClipFromJson(Map<String, dynamic> json) {
  return _Clip.fromJson(json);
}

/// @nodoc
mixin _$Clip {
  String get id => throw _privateConstructorUsedError;
  String get trackId => throw _privateConstructorUsedError;
  String get sourcePath => throw _privateConstructorUsedError;
  int get startMs => throw _privateConstructorUsedError;
  int get endMs => throw _privateConstructorUsedError;
  int get positionMs => throw _privateConstructorUsedError;
  Map<String, dynamic> get transformations =>
      throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  bool get muted => throw _privateConstructorUsedError;

  /// Serializes this Clip to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Clip
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClipCopyWith<Clip> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClipCopyWith<$Res> {
  factory $ClipCopyWith(Clip value, $Res Function(Clip) then) =
      _$ClipCopyWithImpl<$Res, Clip>;
  @useResult
  $Res call({
    String id,
    String trackId,
    String sourcePath,
    int startMs,
    int endMs,
    int positionMs,
    Map<String, dynamic> transformations,
    String? label,
    bool muted,
  });
}

/// @nodoc
class _$ClipCopyWithImpl<$Res, $Val extends Clip>
    implements $ClipCopyWith<$Res> {
  _$ClipCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Clip
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? trackId = null,
    Object? sourcePath = null,
    Object? startMs = null,
    Object? endMs = null,
    Object? positionMs = null,
    Object? transformations = null,
    Object? label = freezed,
    Object? muted = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            trackId: null == trackId
                ? _value.trackId
                : trackId // ignore: cast_nullable_to_non_nullable
                      as String,
            sourcePath: null == sourcePath
                ? _value.sourcePath
                : sourcePath // ignore: cast_nullable_to_non_nullable
                      as String,
            startMs: null == startMs
                ? _value.startMs
                : startMs // ignore: cast_nullable_to_non_nullable
                      as int,
            endMs: null == endMs
                ? _value.endMs
                : endMs // ignore: cast_nullable_to_non_nullable
                      as int,
            positionMs: null == positionMs
                ? _value.positionMs
                : positionMs // ignore: cast_nullable_to_non_nullable
                      as int,
            transformations: null == transformations
                ? _value.transformations
                : transformations // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            label: freezed == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String?,
            muted: null == muted
                ? _value.muted
                : muted // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ClipImplCopyWith<$Res> implements $ClipCopyWith<$Res> {
  factory _$$ClipImplCopyWith(
    _$ClipImpl value,
    $Res Function(_$ClipImpl) then,
  ) = __$$ClipImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String trackId,
    String sourcePath,
    int startMs,
    int endMs,
    int positionMs,
    Map<String, dynamic> transformations,
    String? label,
    bool muted,
  });
}

/// @nodoc
class __$$ClipImplCopyWithImpl<$Res>
    extends _$ClipCopyWithImpl<$Res, _$ClipImpl>
    implements _$$ClipImplCopyWith<$Res> {
  __$$ClipImplCopyWithImpl(_$ClipImpl _value, $Res Function(_$ClipImpl) _then)
    : super(_value, _then);

  /// Create a copy of Clip
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? trackId = null,
    Object? sourcePath = null,
    Object? startMs = null,
    Object? endMs = null,
    Object? positionMs = null,
    Object? transformations = null,
    Object? label = freezed,
    Object? muted = null,
  }) {
    return _then(
      _$ClipImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        trackId: null == trackId
            ? _value.trackId
            : trackId // ignore: cast_nullable_to_non_nullable
                  as String,
        sourcePath: null == sourcePath
            ? _value.sourcePath
            : sourcePath // ignore: cast_nullable_to_non_nullable
                  as String,
        startMs: null == startMs
            ? _value.startMs
            : startMs // ignore: cast_nullable_to_non_nullable
                  as int,
        endMs: null == endMs
            ? _value.endMs
            : endMs // ignore: cast_nullable_to_non_nullable
                  as int,
        positionMs: null == positionMs
            ? _value.positionMs
            : positionMs // ignore: cast_nullable_to_non_nullable
                  as int,
        transformations: null == transformations
            ? _value._transformations
            : transformations // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        label: freezed == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String?,
        muted: null == muted
            ? _value.muted
            : muted // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ClipImpl implements _Clip {
  const _$ClipImpl({
    required this.id,
    required this.trackId,
    required this.sourcePath,
    required this.startMs,
    required this.endMs,
    this.positionMs = 0,
    final Map<String, dynamic> transformations = const {},
    this.label,
    this.muted = false,
  }) : _transformations = transformations;

  factory _$ClipImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClipImplFromJson(json);

  @override
  final String id;
  @override
  final String trackId;
  @override
  final String sourcePath;
  @override
  final int startMs;
  @override
  final int endMs;
  @override
  @JsonKey()
  final int positionMs;
  final Map<String, dynamic> _transformations;
  @override
  @JsonKey()
  Map<String, dynamic> get transformations {
    if (_transformations is EqualUnmodifiableMapView) return _transformations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_transformations);
  }

  @override
  final String? label;
  @override
  @JsonKey()
  final bool muted;

  @override
  String toString() {
    return 'Clip(id: $id, trackId: $trackId, sourcePath: $sourcePath, startMs: $startMs, endMs: $endMs, positionMs: $positionMs, transformations: $transformations, label: $label, muted: $muted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClipImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.trackId, trackId) || other.trackId == trackId) &&
            (identical(other.sourcePath, sourcePath) ||
                other.sourcePath == sourcePath) &&
            (identical(other.startMs, startMs) || other.startMs == startMs) &&
            (identical(other.endMs, endMs) || other.endMs == endMs) &&
            (identical(other.positionMs, positionMs) ||
                other.positionMs == positionMs) &&
            const DeepCollectionEquality().equals(
              other._transformations,
              _transformations,
            ) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.muted, muted) || other.muted == muted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    trackId,
    sourcePath,
    startMs,
    endMs,
    positionMs,
    const DeepCollectionEquality().hash(_transformations),
    label,
    muted,
  );

  /// Create a copy of Clip
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClipImplCopyWith<_$ClipImpl> get copyWith =>
      __$$ClipImplCopyWithImpl<_$ClipImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ClipImplToJson(this);
  }
}

abstract class _Clip implements Clip {
  const factory _Clip({
    required final String id,
    required final String trackId,
    required final String sourcePath,
    required final int startMs,
    required final int endMs,
    final int positionMs,
    final Map<String, dynamic> transformations,
    final String? label,
    final bool muted,
  }) = _$ClipImpl;

  factory _Clip.fromJson(Map<String, dynamic> json) = _$ClipImpl.fromJson;

  @override
  String get id;
  @override
  String get trackId;
  @override
  String get sourcePath;
  @override
  int get startMs;
  @override
  int get endMs;
  @override
  int get positionMs;
  @override
  Map<String, dynamic> get transformations;
  @override
  String? get label;
  @override
  bool get muted;

  /// Create a copy of Clip
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClipImplCopyWith<_$ClipImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
