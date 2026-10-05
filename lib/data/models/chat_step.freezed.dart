// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_step.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatStep {

 String get toolCallId; String get toolName; Map<String, dynamic> get args; String get summary; bool get success; int get durationMs; int get round; ChatStepKind get kind;
/// Create a copy of ChatStep
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatStepCopyWith<ChatStep> get copyWith => _$ChatStepCopyWithImpl<ChatStep>(this as ChatStep, _$identity);

  /// Serializes this ChatStep to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ChatStep;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatStep&&(identical(other.toolCallId, _this.toolCallId) || other.toolCallId == _this.toolCallId)&&(identical(other.toolName, _this.toolName) || other.toolName == _this.toolName)&&const DeepCollectionEquality().equals(other.args, _this.args)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.success, _this.success) || other.success == _this.success)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.round, _this.round) || other.round == _this.round)&&(identical(other.kind, _this.kind) || other.kind == _this.kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ChatStep;
  return Object.hash(runtimeType,_this.toolCallId,_this.toolName,const DeepCollectionEquality().hash(_this.args),_this.summary,_this.success,_this.durationMs,_this.round,_this.kind);
}

@override
String toString() {
  final _this = this as ChatStep;
  return 'ChatStep(toolCallId: ${_this.toolCallId}, toolName: ${_this.toolName}, args: ${_this.args}, summary: ${_this.summary}, success: ${_this.success}, durationMs: ${_this.durationMs}, round: ${_this.round}, kind: ${_this.kind})';
}


}

/// @nodoc
abstract mixin class $ChatStepCopyWith<$Res>  {
  factory $ChatStepCopyWith(ChatStep value, $Res Function(ChatStep) _then) = _$ChatStepCopyWithImpl;
@useResult
$Res call({
 String toolCallId, String toolName, Map<String, dynamic> args, String summary, bool success, int durationMs, int round, ChatStepKind kind
});




}
/// @nodoc
class _$ChatStepCopyWithImpl<$Res>
    implements $ChatStepCopyWith<$Res> {
  _$ChatStepCopyWithImpl(this._self, this._then);

  final ChatStep _self;
  final $Res Function(ChatStep) _then;

/// Create a copy of ChatStep
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolCallId = null,Object? toolName = null,Object? args = null,Object? summary = null,Object? success = null,Object? durationMs = null,Object? round = null,Object? kind = null,}) {
  return _then(ChatStep(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ChatStepKind,
  ));
}

}


/// Adds pattern-matching-related methods to [ChatStep].
extension ChatStepPatterns on ChatStep {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatStep value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatStep() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatStep value)  $default,){
final _that = this;
switch (_that) {
case _ChatStep():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatStep value)?  $default,){
final _that = this;
switch (_that) {
case _ChatStep() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String toolCallId,  String toolName,  Map<String, dynamic> args,  String summary,  bool success,  int durationMs,  int round,  ChatStepKind kind)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatStep() when $default != null:
return $default(_that.toolCallId,_that.toolName,_that.args,_that.summary,_that.success,_that.durationMs,_that.round,_that.kind);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String toolCallId,  String toolName,  Map<String, dynamic> args,  String summary,  bool success,  int durationMs,  int round,  ChatStepKind kind)  $default,) {final _that = this;
switch (_that) {
case _ChatStep():
return $default(_that.toolCallId,_that.toolName,_that.args,_that.summary,_that.success,_that.durationMs,_that.round,_that.kind);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String toolCallId,  String toolName,  Map<String, dynamic> args,  String summary,  bool success,  int durationMs,  int round,  ChatStepKind kind)?  $default,) {final _that = this;
switch (_that) {
case _ChatStep() when $default != null:
return $default(_that.toolCallId,_that.toolName,_that.args,_that.summary,_that.success,_that.durationMs,_that.round,_that.kind);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatStep implements ChatStep {
  const _ChatStep({required this.toolCallId, required this.toolName,  Map<String, dynamic> args = const {}, this.summary = '', this.success = false, this.durationMs = 0, this.round = 0, this.kind = ChatStepKind.read}): _args = args;
  factory _ChatStep.fromJson(Map<String, dynamic> json) => _$ChatStepFromJson(json);

@override final  String toolCallId;
@override final  String toolName;
 final  Map<String, dynamic> _args;
@override@JsonKey() Map<String, dynamic> get args {
  if (_args is EqualUnmodifiableMapView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_args);
}

@override@JsonKey() final  String summary;
@override@JsonKey() final  bool success;
@override@JsonKey() final  int durationMs;
@override@JsonKey() final  int round;
@override@JsonKey() final  ChatStepKind kind;

/// Create a copy of ChatStep
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatStepCopyWith<_ChatStep> get copyWith => __$ChatStepCopyWithImpl<_ChatStep>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatStepToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatStep&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&const DeepCollectionEquality().equals(other.args, _args)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.success, success) || other.success == success)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.round, round) || other.round == round)&&(identical(other.kind, kind) || other.kind == kind));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,toolCallId,toolName,const DeepCollectionEquality().hash(_args),summary,success,durationMs,round,kind);
}

@override
String toString() {
    return 'ChatStep(toolCallId: $toolCallId, toolName: $toolName, args: $args, summary: $summary, success: $success, durationMs: $durationMs, round: $round, kind: $kind)';
}


}

/// @nodoc
abstract mixin class _$ChatStepCopyWith<$Res> implements $ChatStepCopyWith<$Res> {
  factory _$ChatStepCopyWith(_ChatStep value, $Res Function(_ChatStep) _then) = __$ChatStepCopyWithImpl;
@override @useResult
$Res call({
 String toolCallId, String toolName, Map<String, dynamic> args, String summary, bool success, int durationMs, int round, ChatStepKind kind
});




}
/// @nodoc
class __$ChatStepCopyWithImpl<$Res>
    implements _$ChatStepCopyWith<$Res> {
  __$ChatStepCopyWithImpl(this._self, this._then);

  final _ChatStep _self;
  final $Res Function(_ChatStep) _then;

/// Create a copy of ChatStep
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? toolName = null,Object? args = null,Object? summary = null,Object? success = null,Object? durationMs = null,Object? round = null,Object? kind = null,}) {
  return _then(_ChatStep(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as ChatStepKind,
  ));
}


}

// dart format on
