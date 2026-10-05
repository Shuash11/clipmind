// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Clip {

 String get id; String get trackId; String get sourcePath; int get startMs; int get endMs; int get positionMs; Map<String, dynamic> get transformations; String? get label; bool get muted;
/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClipCopyWith<Clip> get copyWith => _$ClipCopyWithImpl<Clip>(this as Clip, _$identity);

  /// Serializes this Clip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Clip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Clip&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.trackId, _this.trackId) || other.trackId == _this.trackId)&&(identical(other.sourcePath, _this.sourcePath) || other.sourcePath == _this.sourcePath)&&(identical(other.startMs, _this.startMs) || other.startMs == _this.startMs)&&(identical(other.endMs, _this.endMs) || other.endMs == _this.endMs)&&(identical(other.positionMs, _this.positionMs) || other.positionMs == _this.positionMs)&&const DeepCollectionEquality().equals(other.transformations, _this.transformations)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.muted, _this.muted) || other.muted == _this.muted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Clip;
  return Object.hash(runtimeType,_this.id,_this.trackId,_this.sourcePath,_this.startMs,_this.endMs,_this.positionMs,const DeepCollectionEquality().hash(_this.transformations),_this.label,_this.muted);
}

@override
String toString() {
  final _this = this as Clip;
  return 'Clip(id: ${_this.id}, trackId: ${_this.trackId}, sourcePath: ${_this.sourcePath}, startMs: ${_this.startMs}, endMs: ${_this.endMs}, positionMs: ${_this.positionMs}, transformations: ${_this.transformations}, label: ${_this.label}, muted: ${_this.muted})';
}


}

/// @nodoc
abstract mixin class $ClipCopyWith<$Res>  {
  factory $ClipCopyWith(Clip value, $Res Function(Clip) _then) = _$ClipCopyWithImpl;
@useResult
$Res call({
 String id, String trackId, String sourcePath, int startMs, int endMs, int positionMs, Map<String, dynamic> transformations, String? label, bool muted
});




}
/// @nodoc
class _$ClipCopyWithImpl<$Res>
    implements $ClipCopyWith<$Res> {
  _$ClipCopyWithImpl(this._self, this._then);

  final Clip _self;
  final $Res Function(Clip) _then;

/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? trackId = null,Object? sourcePath = null,Object? startMs = null,Object? endMs = null,Object? positionMs = null,Object? transformations = null,Object? label = freezed,Object? muted = null,}) {
  return _then(Clip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,sourcePath: null == sourcePath ? _self.sourcePath : sourcePath // ignore: cast_nullable_to_non_nullable
as String,startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,positionMs: null == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as int,transformations: null == transformations ? _self.transformations : transformations // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Clip].
extension ClipPatterns on Clip {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Clip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Clip() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Clip value)  $default,){
final _that = this;
switch (_that) {
case _Clip():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Clip value)?  $default,){
final _that = this;
switch (_that) {
case _Clip() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String trackId,  String sourcePath,  int startMs,  int endMs,  int positionMs,  Map<String, dynamic> transformations,  String? label,  bool muted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Clip() when $default != null:
return $default(_that.id,_that.trackId,_that.sourcePath,_that.startMs,_that.endMs,_that.positionMs,_that.transformations,_that.label,_that.muted);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String trackId,  String sourcePath,  int startMs,  int endMs,  int positionMs,  Map<String, dynamic> transformations,  String? label,  bool muted)  $default,) {final _that = this;
switch (_that) {
case _Clip():
return $default(_that.id,_that.trackId,_that.sourcePath,_that.startMs,_that.endMs,_that.positionMs,_that.transformations,_that.label,_that.muted);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String trackId,  String sourcePath,  int startMs,  int endMs,  int positionMs,  Map<String, dynamic> transformations,  String? label,  bool muted)?  $default,) {final _that = this;
switch (_that) {
case _Clip() when $default != null:
return $default(_that.id,_that.trackId,_that.sourcePath,_that.startMs,_that.endMs,_that.positionMs,_that.transformations,_that.label,_that.muted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Clip implements Clip {
  const _Clip({required this.id, required this.trackId, required this.sourcePath, required this.startMs, required this.endMs, this.positionMs = 0,  Map<String, dynamic> transformations = const {}, this.label, this.muted = false}): _transformations = transformations;
  factory _Clip.fromJson(Map<String, dynamic> json) => _$ClipFromJson(json);

@override final  String id;
@override final  String trackId;
@override final  String sourcePath;
@override final  int startMs;
@override final  int endMs;
@override@JsonKey() final  int positionMs;
 final  Map<String, dynamic> _transformations;
@override@JsonKey() Map<String, dynamic> get transformations {
  if (_transformations is EqualUnmodifiableMapView) return _transformations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_transformations);
}

@override final  String? label;
@override@JsonKey() final  bool muted;

/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClipCopyWith<_Clip> get copyWith => __$ClipCopyWithImpl<_Clip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Clip&&(identical(other.id, id) || other.id == id)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.sourcePath, sourcePath) || other.sourcePath == sourcePath)&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs)&&const DeepCollectionEquality().equals(other.transformations, _transformations)&&(identical(other.label, label) || other.label == label)&&(identical(other.muted, muted) || other.muted == muted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,trackId,sourcePath,startMs,endMs,positionMs,const DeepCollectionEquality().hash(_transformations),label,muted);
}

@override
String toString() {
    return 'Clip(id: $id, trackId: $trackId, sourcePath: $sourcePath, startMs: $startMs, endMs: $endMs, positionMs: $positionMs, transformations: $transformations, label: $label, muted: $muted)';
}


}

/// @nodoc
abstract mixin class _$ClipCopyWith<$Res> implements $ClipCopyWith<$Res> {
  factory _$ClipCopyWith(_Clip value, $Res Function(_Clip) _then) = __$ClipCopyWithImpl;
@override @useResult
$Res call({
 String id, String trackId, String sourcePath, int startMs, int endMs, int positionMs, Map<String, dynamic> transformations, String? label, bool muted
});




}
/// @nodoc
class __$ClipCopyWithImpl<$Res>
    implements _$ClipCopyWith<$Res> {
  __$ClipCopyWithImpl(this._self, this._then);

  final _Clip _self;
  final $Res Function(_Clip) _then;

/// Create a copy of Clip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? trackId = null,Object? sourcePath = null,Object? startMs = null,Object? endMs = null,Object? positionMs = null,Object? transformations = null,Object? label = freezed,Object? muted = null,}) {
  return _then(_Clip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,sourcePath: null == sourcePath ? _self.sourcePath : sourcePath // ignore: cast_nullable_to_non_nullable
as String,startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,positionMs: null == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as int,transformations: null == transformations ? _self._transformations : transformations // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
