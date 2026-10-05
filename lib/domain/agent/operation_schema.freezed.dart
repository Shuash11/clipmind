// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'operation_schema.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EditOperationSet {

 List<EditOperationRequest> get operations; String get summary;@JsonKey(name: 'clarification_needed') String? get clarificationNeeded;
/// Create a copy of EditOperationSet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EditOperationSetCopyWith<EditOperationSet> get copyWith => _$EditOperationSetCopyWithImpl<EditOperationSet>(this as EditOperationSet, _$identity);

  /// Serializes this EditOperationSet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EditOperationSet;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EditOperationSet&&const DeepCollectionEquality().equals(other.operations, _this.operations)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.clarificationNeeded, _this.clarificationNeeded) || other.clarificationNeeded == _this.clarificationNeeded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EditOperationSet;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.operations),_this.summary,_this.clarificationNeeded);
}

@override
String toString() {
  final _this = this as EditOperationSet;
  return 'EditOperationSet(operations: ${_this.operations}, summary: ${_this.summary}, clarificationNeeded: ${_this.clarificationNeeded})';
}


}

/// @nodoc
abstract mixin class $EditOperationSetCopyWith<$Res>  {
  factory $EditOperationSetCopyWith(EditOperationSet value, $Res Function(EditOperationSet) _then) = _$EditOperationSetCopyWithImpl;
@useResult
$Res call({
 List<EditOperationRequest> operations, String summary,@JsonKey(name: 'clarification_needed') String? clarificationNeeded
});




}
/// @nodoc
class _$EditOperationSetCopyWithImpl<$Res>
    implements $EditOperationSetCopyWith<$Res> {
  _$EditOperationSetCopyWithImpl(this._self, this._then);

  final EditOperationSet _self;
  final $Res Function(EditOperationSet) _then;

/// Create a copy of EditOperationSet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? operations = null,Object? summary = null,Object? clarificationNeeded = freezed,}) {
  return _then(EditOperationSet(
operations: null == operations ? _self.operations : operations // ignore: cast_nullable_to_non_nullable
as List<EditOperationRequest>,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,clarificationNeeded: freezed == clarificationNeeded ? _self.clarificationNeeded : clarificationNeeded // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EditOperationSet].
extension EditOperationSetPatterns on EditOperationSet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EditOperationSet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EditOperationSet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EditOperationSet value)  $default,){
final _that = this;
switch (_that) {
case _EditOperationSet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EditOperationSet value)?  $default,){
final _that = this;
switch (_that) {
case _EditOperationSet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<EditOperationRequest> operations,  String summary, @JsonKey(name: 'clarification_needed')  String? clarificationNeeded)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EditOperationSet() when $default != null:
return $default(_that.operations,_that.summary,_that.clarificationNeeded);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<EditOperationRequest> operations,  String summary, @JsonKey(name: 'clarification_needed')  String? clarificationNeeded)  $default,) {final _that = this;
switch (_that) {
case _EditOperationSet():
return $default(_that.operations,_that.summary,_that.clarificationNeeded);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<EditOperationRequest> operations,  String summary, @JsonKey(name: 'clarification_needed')  String? clarificationNeeded)?  $default,) {final _that = this;
switch (_that) {
case _EditOperationSet() when $default != null:
return $default(_that.operations,_that.summary,_that.clarificationNeeded);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EditOperationSet implements EditOperationSet {
  const _EditOperationSet({required  List<EditOperationRequest> operations, required this.summary, @JsonKey(name: 'clarification_needed') this.clarificationNeeded}): _operations = operations;
  factory _EditOperationSet.fromJson(Map<String, dynamic> json) => _$EditOperationSetFromJson(json);

 final  List<EditOperationRequest> _operations;
@override List<EditOperationRequest> get operations {
  if (_operations is EqualUnmodifiableListView) return _operations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_operations);
}

@override final  String summary;
@override@JsonKey(name: 'clarification_needed') final  String? clarificationNeeded;

/// Create a copy of EditOperationSet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EditOperationSetCopyWith<_EditOperationSet> get copyWith => __$EditOperationSetCopyWithImpl<_EditOperationSet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EditOperationSetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EditOperationSet&&const DeepCollectionEquality().equals(other.operations, _operations)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.clarificationNeeded, clarificationNeeded) || other.clarificationNeeded == clarificationNeeded));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_operations),summary,clarificationNeeded);
}

@override
String toString() {
    return 'EditOperationSet(operations: $operations, summary: $summary, clarificationNeeded: $clarificationNeeded)';
}


}

/// @nodoc
abstract mixin class _$EditOperationSetCopyWith<$Res> implements $EditOperationSetCopyWith<$Res> {
  factory _$EditOperationSetCopyWith(_EditOperationSet value, $Res Function(_EditOperationSet) _then) = __$EditOperationSetCopyWithImpl;
@override @useResult
$Res call({
 List<EditOperationRequest> operations, String summary,@JsonKey(name: 'clarification_needed') String? clarificationNeeded
});




}
/// @nodoc
class __$EditOperationSetCopyWithImpl<$Res>
    implements _$EditOperationSetCopyWith<$Res> {
  __$EditOperationSetCopyWithImpl(this._self, this._then);

  final _EditOperationSet _self;
  final $Res Function(_EditOperationSet) _then;

/// Create a copy of EditOperationSet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? operations = null,Object? summary = null,Object? clarificationNeeded = freezed,}) {
  return _then(_EditOperationSet(
operations: null == operations ? _self._operations : operations // ignore: cast_nullable_to_non_nullable
as List<EditOperationRequest>,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,clarificationNeeded: freezed == clarificationNeeded ? _self.clarificationNeeded : clarificationNeeded // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$EditOperationRequest {

 String get id; String get type;@JsonKey(name: 'target_clip_id') dynamic get targetClipId; Map<String, dynamic> get params;
/// Create a copy of EditOperationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EditOperationRequestCopyWith<EditOperationRequest> get copyWith => _$EditOperationRequestCopyWithImpl<EditOperationRequest>(this as EditOperationRequest, _$identity);

  /// Serializes this EditOperationRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EditOperationRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EditOperationRequest&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&const DeepCollectionEquality().equals(other.targetClipId, _this.targetClipId)&&const DeepCollectionEquality().equals(other.params, _this.params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EditOperationRequest;
  return Object.hash(runtimeType,_this.id,_this.type,const DeepCollectionEquality().hash(_this.targetClipId),const DeepCollectionEquality().hash(_this.params));
}

@override
String toString() {
  final _this = this as EditOperationRequest;
  return 'EditOperationRequest(id: ${_this.id}, type: ${_this.type}, targetClipId: ${_this.targetClipId}, params: ${_this.params})';
}


}

/// @nodoc
abstract mixin class $EditOperationRequestCopyWith<$Res>  {
  factory $EditOperationRequestCopyWith(EditOperationRequest value, $Res Function(EditOperationRequest) _then) = _$EditOperationRequestCopyWithImpl;
@useResult
$Res call({
 String id, String type,@JsonKey(name: 'target_clip_id') dynamic targetClipId, Map<String, dynamic> params
});




}
/// @nodoc
class _$EditOperationRequestCopyWithImpl<$Res>
    implements $EditOperationRequestCopyWith<$Res> {
  _$EditOperationRequestCopyWithImpl(this._self, this._then);

  final EditOperationRequest _self;
  final $Res Function(EditOperationRequest) _then;

/// Create a copy of EditOperationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? targetClipId = freezed,Object? params = null,}) {
  return _then(EditOperationRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,targetClipId: freezed == targetClipId ? _self.targetClipId : targetClipId // ignore: cast_nullable_to_non_nullable
as dynamic,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [EditOperationRequest].
extension EditOperationRequestPatterns on EditOperationRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EditOperationRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EditOperationRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EditOperationRequest value)  $default,){
final _that = this;
switch (_that) {
case _EditOperationRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EditOperationRequest value)?  $default,){
final _that = this;
switch (_that) {
case _EditOperationRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type, @JsonKey(name: 'target_clip_id')  dynamic targetClipId,  Map<String, dynamic> params)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EditOperationRequest() when $default != null:
return $default(_that.id,_that.type,_that.targetClipId,_that.params);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type, @JsonKey(name: 'target_clip_id')  dynamic targetClipId,  Map<String, dynamic> params)  $default,) {final _that = this;
switch (_that) {
case _EditOperationRequest():
return $default(_that.id,_that.type,_that.targetClipId,_that.params);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type, @JsonKey(name: 'target_clip_id')  dynamic targetClipId,  Map<String, dynamic> params)?  $default,) {final _that = this;
switch (_that) {
case _EditOperationRequest() when $default != null:
return $default(_that.id,_that.type,_that.targetClipId,_that.params);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EditOperationRequest implements EditOperationRequest {
  const _EditOperationRequest({required this.id, required this.type, @JsonKey(name: 'target_clip_id') required this.targetClipId, required  Map<String, dynamic> params}): _params = params;
  factory _EditOperationRequest.fromJson(Map<String, dynamic> json) => _$EditOperationRequestFromJson(json);

@override final  String id;
@override final  String type;
@override@JsonKey(name: 'target_clip_id') final  dynamic targetClipId;
 final  Map<String, dynamic> _params;
@override Map<String, dynamic> get params {
  if (_params is EqualUnmodifiableMapView) return _params;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_params);
}


/// Create a copy of EditOperationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EditOperationRequestCopyWith<_EditOperationRequest> get copyWith => __$EditOperationRequestCopyWithImpl<_EditOperationRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EditOperationRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EditOperationRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.targetClipId, targetClipId)&&const DeepCollectionEquality().equals(other.params, _params));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,type,const DeepCollectionEquality().hash(targetClipId),const DeepCollectionEquality().hash(_params));
}

@override
String toString() {
    return 'EditOperationRequest(id: $id, type: $type, targetClipId: $targetClipId, params: $params)';
}


}

/// @nodoc
abstract mixin class _$EditOperationRequestCopyWith<$Res> implements $EditOperationRequestCopyWith<$Res> {
  factory _$EditOperationRequestCopyWith(_EditOperationRequest value, $Res Function(_EditOperationRequest) _then) = __$EditOperationRequestCopyWithImpl;
@override @useResult
$Res call({
 String id, String type,@JsonKey(name: 'target_clip_id') dynamic targetClipId, Map<String, dynamic> params
});




}
/// @nodoc
class __$EditOperationRequestCopyWithImpl<$Res>
    implements _$EditOperationRequestCopyWith<$Res> {
  __$EditOperationRequestCopyWithImpl(this._self, this._then);

  final _EditOperationRequest _self;
  final $Res Function(_EditOperationRequest) _then;

/// Create a copy of EditOperationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? targetClipId = freezed,Object? params = null,}) {
  return _then(_EditOperationRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,targetClipId: freezed == targetClipId ? _self.targetClipId : targetClipId // ignore: cast_nullable_to_non_nullable
as dynamic,params: null == params ? _self._params : params // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

/// @nodoc
mixin _$ValidatedCommand {

 String get text; Map<String, int> get normalizedTimecodes; ProjectSnapshot get projectSnapshot;
/// Create a copy of ValidatedCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ValidatedCommandCopyWith<ValidatedCommand> get copyWith => _$ValidatedCommandCopyWithImpl<ValidatedCommand>(this as ValidatedCommand, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ValidatedCommand;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ValidatedCommand&&(identical(other.text, _this.text) || other.text == _this.text)&&const DeepCollectionEquality().equals(other.normalizedTimecodes, _this.normalizedTimecodes)&&(identical(other.projectSnapshot, _this.projectSnapshot) || other.projectSnapshot == _this.projectSnapshot));
}


@override
int get hashCode {
  final _this = this as ValidatedCommand;
  return Object.hash(runtimeType,_this.text,const DeepCollectionEquality().hash(_this.normalizedTimecodes),_this.projectSnapshot);
}

@override
String toString() {
  final _this = this as ValidatedCommand;
  return 'ValidatedCommand(text: ${_this.text}, normalizedTimecodes: ${_this.normalizedTimecodes}, projectSnapshot: ${_this.projectSnapshot})';
}


}

/// @nodoc
abstract mixin class $ValidatedCommandCopyWith<$Res>  {
  factory $ValidatedCommandCopyWith(ValidatedCommand value, $Res Function(ValidatedCommand) _then) = _$ValidatedCommandCopyWithImpl;
@useResult
$Res call({
 String text, Map<String, int> normalizedTimecodes, ProjectSnapshot projectSnapshot
});


$ProjectSnapshotCopyWith<$Res> get projectSnapshot;

}
/// @nodoc
class _$ValidatedCommandCopyWithImpl<$Res>
    implements $ValidatedCommandCopyWith<$Res> {
  _$ValidatedCommandCopyWithImpl(this._self, this._then);

  final ValidatedCommand _self;
  final $Res Function(ValidatedCommand) _then;

/// Create a copy of ValidatedCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? normalizedTimecodes = null,Object? projectSnapshot = null,}) {
  return _then(ValidatedCommand(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,normalizedTimecodes: null == normalizedTimecodes ? _self.normalizedTimecodes : normalizedTimecodes // ignore: cast_nullable_to_non_nullable
as Map<String, int>,projectSnapshot: null == projectSnapshot ? _self.projectSnapshot : projectSnapshot // ignore: cast_nullable_to_non_nullable
as ProjectSnapshot,
  ));
}
/// Create a copy of ValidatedCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSnapshotCopyWith<$Res> get projectSnapshot {
  
  return $ProjectSnapshotCopyWith<$Res>(_self.projectSnapshot, (value) {
    return _then(_self.copyWith(projectSnapshot: value));
  });
}
}


/// Adds pattern-matching-related methods to [ValidatedCommand].
extension ValidatedCommandPatterns on ValidatedCommand {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ValidatedCommand value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ValidatedCommand() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ValidatedCommand value)  $default,){
final _that = this;
switch (_that) {
case _ValidatedCommand():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ValidatedCommand value)?  $default,){
final _that = this;
switch (_that) {
case _ValidatedCommand() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  Map<String, int> normalizedTimecodes,  ProjectSnapshot projectSnapshot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ValidatedCommand() when $default != null:
return $default(_that.text,_that.normalizedTimecodes,_that.projectSnapshot);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  Map<String, int> normalizedTimecodes,  ProjectSnapshot projectSnapshot)  $default,) {final _that = this;
switch (_that) {
case _ValidatedCommand():
return $default(_that.text,_that.normalizedTimecodes,_that.projectSnapshot);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  Map<String, int> normalizedTimecodes,  ProjectSnapshot projectSnapshot)?  $default,) {final _that = this;
switch (_that) {
case _ValidatedCommand() when $default != null:
return $default(_that.text,_that.normalizedTimecodes,_that.projectSnapshot);case _:
  return null;

}
}

}

/// @nodoc


class _ValidatedCommand implements ValidatedCommand {
  const _ValidatedCommand({required this.text, required  Map<String, int> normalizedTimecodes, required this.projectSnapshot}): _normalizedTimecodes = normalizedTimecodes;
  

@override final  String text;
 final  Map<String, int> _normalizedTimecodes;
@override Map<String, int> get normalizedTimecodes {
  if (_normalizedTimecodes is EqualUnmodifiableMapView) return _normalizedTimecodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_normalizedTimecodes);
}

@override final  ProjectSnapshot projectSnapshot;

/// Create a copy of ValidatedCommand
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ValidatedCommandCopyWith<_ValidatedCommand> get copyWith => __$ValidatedCommandCopyWithImpl<_ValidatedCommand>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ValidatedCommand&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.normalizedTimecodes, _normalizedTimecodes)&&(identical(other.projectSnapshot, projectSnapshot) || other.projectSnapshot == projectSnapshot));
}


@override
int get hashCode {
    return Object.hash(runtimeType,text,const DeepCollectionEquality().hash(_normalizedTimecodes),projectSnapshot);
}

@override
String toString() {
    return 'ValidatedCommand(text: $text, normalizedTimecodes: $normalizedTimecodes, projectSnapshot: $projectSnapshot)';
}


}

/// @nodoc
abstract mixin class _$ValidatedCommandCopyWith<$Res> implements $ValidatedCommandCopyWith<$Res> {
  factory _$ValidatedCommandCopyWith(_ValidatedCommand value, $Res Function(_ValidatedCommand) _then) = __$ValidatedCommandCopyWithImpl;
@override @useResult
$Res call({
 String text, Map<String, int> normalizedTimecodes, ProjectSnapshot projectSnapshot
});


@override $ProjectSnapshotCopyWith<$Res> get projectSnapshot;

}
/// @nodoc
class __$ValidatedCommandCopyWithImpl<$Res>
    implements _$ValidatedCommandCopyWith<$Res> {
  __$ValidatedCommandCopyWithImpl(this._self, this._then);

  final _ValidatedCommand _self;
  final $Res Function(_ValidatedCommand) _then;

/// Create a copy of ValidatedCommand
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? normalizedTimecodes = null,Object? projectSnapshot = null,}) {
  return _then(_ValidatedCommand(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,normalizedTimecodes: null == normalizedTimecodes ? _self._normalizedTimecodes : normalizedTimecodes // ignore: cast_nullable_to_non_nullable
as Map<String, int>,projectSnapshot: null == projectSnapshot ? _self.projectSnapshot : projectSnapshot // ignore: cast_nullable_to_non_nullable
as ProjectSnapshot,
  ));
}

/// Create a copy of ValidatedCommand
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectSnapshotCopyWith<$Res> get projectSnapshot {
  
  return $ProjectSnapshotCopyWith<$Res>(_self.projectSnapshot, (value) {
    return _then(_self.copyWith(projectSnapshot: value));
  });
}
}

/// @nodoc
mixin _$ProjectSnapshot {

 int get durationMs; int get width; int get height; double get fps; String get codec; bool get hasAudio; List<ClipSnapshot> get clips; bool get metadataVerified;
/// Create a copy of ProjectSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSnapshotCopyWith<ProjectSnapshot> get copyWith => _$ProjectSnapshotCopyWithImpl<ProjectSnapshot>(this as ProjectSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ProjectSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSnapshot&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.fps, _this.fps) || other.fps == _this.fps)&&(identical(other.codec, _this.codec) || other.codec == _this.codec)&&(identical(other.hasAudio, _this.hasAudio) || other.hasAudio == _this.hasAudio)&&const DeepCollectionEquality().equals(other.clips, _this.clips)&&(identical(other.metadataVerified, _this.metadataVerified) || other.metadataVerified == _this.metadataVerified));
}


@override
int get hashCode {
  final _this = this as ProjectSnapshot;
  return Object.hash(runtimeType,_this.durationMs,_this.width,_this.height,_this.fps,_this.codec,_this.hasAudio,const DeepCollectionEquality().hash(_this.clips),_this.metadataVerified);
}

@override
String toString() {
  final _this = this as ProjectSnapshot;
  return 'ProjectSnapshot(durationMs: ${_this.durationMs}, width: ${_this.width}, height: ${_this.height}, fps: ${_this.fps}, codec: ${_this.codec}, hasAudio: ${_this.hasAudio}, clips: ${_this.clips}, metadataVerified: ${_this.metadataVerified})';
}


}

/// @nodoc
abstract mixin class $ProjectSnapshotCopyWith<$Res>  {
  factory $ProjectSnapshotCopyWith(ProjectSnapshot value, $Res Function(ProjectSnapshot) _then) = _$ProjectSnapshotCopyWithImpl;
@useResult
$Res call({
 int durationMs, int width, int height, double fps, String codec, bool hasAudio, List<ClipSnapshot> clips, bool metadataVerified
});




}
/// @nodoc
class _$ProjectSnapshotCopyWithImpl<$Res>
    implements $ProjectSnapshotCopyWith<$Res> {
  _$ProjectSnapshotCopyWithImpl(this._self, this._then);

  final ProjectSnapshot _self;
  final $Res Function(ProjectSnapshot) _then;

/// Create a copy of ProjectSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? durationMs = null,Object? width = null,Object? height = null,Object? fps = null,Object? codec = null,Object? hasAudio = null,Object? clips = null,Object? metadataVerified = null,}) {
  return _then(ProjectSnapshot(
durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,hasAudio: null == hasAudio ? _self.hasAudio : hasAudio // ignore: cast_nullable_to_non_nullable
as bool,clips: null == clips ? _self.clips : clips // ignore: cast_nullable_to_non_nullable
as List<ClipSnapshot>,metadataVerified: null == metadataVerified ? _self.metadataVerified : metadataVerified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectSnapshot].
extension ProjectSnapshotPatterns on ProjectSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int durationMs,  int width,  int height,  double fps,  String codec,  bool hasAudio,  List<ClipSnapshot> clips,  bool metadataVerified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectSnapshot() when $default != null:
return $default(_that.durationMs,_that.width,_that.height,_that.fps,_that.codec,_that.hasAudio,_that.clips,_that.metadataVerified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int durationMs,  int width,  int height,  double fps,  String codec,  bool hasAudio,  List<ClipSnapshot> clips,  bool metadataVerified)  $default,) {final _that = this;
switch (_that) {
case _ProjectSnapshot():
return $default(_that.durationMs,_that.width,_that.height,_that.fps,_that.codec,_that.hasAudio,_that.clips,_that.metadataVerified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int durationMs,  int width,  int height,  double fps,  String codec,  bool hasAudio,  List<ClipSnapshot> clips,  bool metadataVerified)?  $default,) {final _that = this;
switch (_that) {
case _ProjectSnapshot() when $default != null:
return $default(_that.durationMs,_that.width,_that.height,_that.fps,_that.codec,_that.hasAudio,_that.clips,_that.metadataVerified);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectSnapshot implements ProjectSnapshot {
  const _ProjectSnapshot({required this.durationMs, required this.width, required this.height, required this.fps, required this.codec, required this.hasAudio, required  List<ClipSnapshot> clips, this.metadataVerified = false}): _clips = clips;
  

@override final  int durationMs;
@override final  int width;
@override final  int height;
@override final  double fps;
@override final  String codec;
@override final  bool hasAudio;
 final  List<ClipSnapshot> _clips;
@override List<ClipSnapshot> get clips {
  if (_clips is EqualUnmodifiableListView) return _clips;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clips);
}

@override@JsonKey() final  bool metadataVerified;

/// Create a copy of ProjectSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSnapshotCopyWith<_ProjectSnapshot> get copyWith => __$ProjectSnapshotCopyWithImpl<_ProjectSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSnapshot&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.hasAudio, hasAudio) || other.hasAudio == hasAudio)&&const DeepCollectionEquality().equals(other.clips, _clips)&&(identical(other.metadataVerified, metadataVerified) || other.metadataVerified == metadataVerified));
}


@override
int get hashCode {
    return Object.hash(runtimeType,durationMs,width,height,fps,codec,hasAudio,const DeepCollectionEquality().hash(_clips),metadataVerified);
}

@override
String toString() {
    return 'ProjectSnapshot(durationMs: $durationMs, width: $width, height: $height, fps: $fps, codec: $codec, hasAudio: $hasAudio, clips: $clips, metadataVerified: $metadataVerified)';
}


}

/// @nodoc
abstract mixin class _$ProjectSnapshotCopyWith<$Res> implements $ProjectSnapshotCopyWith<$Res> {
  factory _$ProjectSnapshotCopyWith(_ProjectSnapshot value, $Res Function(_ProjectSnapshot) _then) = __$ProjectSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int durationMs, int width, int height, double fps, String codec, bool hasAudio, List<ClipSnapshot> clips, bool metadataVerified
});




}
/// @nodoc
class __$ProjectSnapshotCopyWithImpl<$Res>
    implements _$ProjectSnapshotCopyWith<$Res> {
  __$ProjectSnapshotCopyWithImpl(this._self, this._then);

  final _ProjectSnapshot _self;
  final $Res Function(_ProjectSnapshot) _then;

/// Create a copy of ProjectSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? durationMs = null,Object? width = null,Object? height = null,Object? fps = null,Object? codec = null,Object? hasAudio = null,Object? clips = null,Object? metadataVerified = null,}) {
  return _then(_ProjectSnapshot(
durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,hasAudio: null == hasAudio ? _self.hasAudio : hasAudio // ignore: cast_nullable_to_non_nullable
as bool,clips: null == clips ? _self._clips : clips // ignore: cast_nullable_to_non_nullable
as List<ClipSnapshot>,metadataVerified: null == metadataVerified ? _self.metadataVerified : metadataVerified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ClipSnapshot {

 String get id; String get trackId; String get label; int get startMs; int get endMs; int get positionMs;
/// Create a copy of ClipSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClipSnapshotCopyWith<ClipSnapshot> get copyWith => _$ClipSnapshotCopyWithImpl<ClipSnapshot>(this as ClipSnapshot, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ClipSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClipSnapshot&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.trackId, _this.trackId) || other.trackId == _this.trackId)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.startMs, _this.startMs) || other.startMs == _this.startMs)&&(identical(other.endMs, _this.endMs) || other.endMs == _this.endMs)&&(identical(other.positionMs, _this.positionMs) || other.positionMs == _this.positionMs));
}


@override
int get hashCode {
  final _this = this as ClipSnapshot;
  return Object.hash(runtimeType,_this.id,_this.trackId,_this.label,_this.startMs,_this.endMs,_this.positionMs);
}

@override
String toString() {
  final _this = this as ClipSnapshot;
  return 'ClipSnapshot(id: ${_this.id}, trackId: ${_this.trackId}, label: ${_this.label}, startMs: ${_this.startMs}, endMs: ${_this.endMs}, positionMs: ${_this.positionMs})';
}


}

/// @nodoc
abstract mixin class $ClipSnapshotCopyWith<$Res>  {
  factory $ClipSnapshotCopyWith(ClipSnapshot value, $Res Function(ClipSnapshot) _then) = _$ClipSnapshotCopyWithImpl;
@useResult
$Res call({
 String id, String trackId, String label, int startMs, int endMs, int positionMs
});




}
/// @nodoc
class _$ClipSnapshotCopyWithImpl<$Res>
    implements $ClipSnapshotCopyWith<$Res> {
  _$ClipSnapshotCopyWithImpl(this._self, this._then);

  final ClipSnapshot _self;
  final $Res Function(ClipSnapshot) _then;

/// Create a copy of ClipSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? trackId = null,Object? label = null,Object? startMs = null,Object? endMs = null,Object? positionMs = null,}) {
  return _then(ClipSnapshot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,positionMs: null == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ClipSnapshot].
extension ClipSnapshotPatterns on ClipSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClipSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClipSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClipSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _ClipSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClipSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _ClipSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String trackId,  String label,  int startMs,  int endMs,  int positionMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClipSnapshot() when $default != null:
return $default(_that.id,_that.trackId,_that.label,_that.startMs,_that.endMs,_that.positionMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String trackId,  String label,  int startMs,  int endMs,  int positionMs)  $default,) {final _that = this;
switch (_that) {
case _ClipSnapshot():
return $default(_that.id,_that.trackId,_that.label,_that.startMs,_that.endMs,_that.positionMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String trackId,  String label,  int startMs,  int endMs,  int positionMs)?  $default,) {final _that = this;
switch (_that) {
case _ClipSnapshot() when $default != null:
return $default(_that.id,_that.trackId,_that.label,_that.startMs,_that.endMs,_that.positionMs);case _:
  return null;

}
}

}

/// @nodoc


class _ClipSnapshot implements ClipSnapshot {
  const _ClipSnapshot({required this.id, required this.trackId, required this.label, required this.startMs, required this.endMs, required this.positionMs});
  

@override final  String id;
@override final  String trackId;
@override final  String label;
@override final  int startMs;
@override final  int endMs;
@override final  int positionMs;

/// Create a copy of ClipSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClipSnapshotCopyWith<_ClipSnapshot> get copyWith => __$ClipSnapshotCopyWithImpl<_ClipSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClipSnapshot&&(identical(other.id, id) || other.id == id)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.label, label) || other.label == label)&&(identical(other.startMs, startMs) || other.startMs == startMs)&&(identical(other.endMs, endMs) || other.endMs == endMs)&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,trackId,label,startMs,endMs,positionMs);
}

@override
String toString() {
    return 'ClipSnapshot(id: $id, trackId: $trackId, label: $label, startMs: $startMs, endMs: $endMs, positionMs: $positionMs)';
}


}

/// @nodoc
abstract mixin class _$ClipSnapshotCopyWith<$Res> implements $ClipSnapshotCopyWith<$Res> {
  factory _$ClipSnapshotCopyWith(_ClipSnapshot value, $Res Function(_ClipSnapshot) _then) = __$ClipSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String id, String trackId, String label, int startMs, int endMs, int positionMs
});




}
/// @nodoc
class __$ClipSnapshotCopyWithImpl<$Res>
    implements _$ClipSnapshotCopyWith<$Res> {
  __$ClipSnapshotCopyWithImpl(this._self, this._then);

  final _ClipSnapshot _self;
  final $Res Function(_ClipSnapshot) _then;

/// Create a copy of ClipSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? trackId = null,Object? label = null,Object? startMs = null,Object? endMs = null,Object? positionMs = null,}) {
  return _then(_ClipSnapshot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,trackId: null == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,startMs: null == startMs ? _self.startMs : startMs // ignore: cast_nullable_to_non_nullable
as int,endMs: null == endMs ? _self.endMs : endMs // ignore: cast_nullable_to_non_nullable
as int,positionMs: null == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$AgentRequest {

 String get systemPrompt; String get userCommand; String get schemaJson; int get timeoutSeconds;
/// Create a copy of AgentRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentRequestCopyWith<AgentRequest> get copyWith => _$AgentRequestCopyWithImpl<AgentRequest>(this as AgentRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AgentRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentRequest&&(identical(other.systemPrompt, _this.systemPrompt) || other.systemPrompt == _this.systemPrompt)&&(identical(other.userCommand, _this.userCommand) || other.userCommand == _this.userCommand)&&(identical(other.schemaJson, _this.schemaJson) || other.schemaJson == _this.schemaJson)&&(identical(other.timeoutSeconds, _this.timeoutSeconds) || other.timeoutSeconds == _this.timeoutSeconds));
}


@override
int get hashCode {
  final _this = this as AgentRequest;
  return Object.hash(runtimeType,_this.systemPrompt,_this.userCommand,_this.schemaJson,_this.timeoutSeconds);
}

@override
String toString() {
  final _this = this as AgentRequest;
  return 'AgentRequest(systemPrompt: ${_this.systemPrompt}, userCommand: ${_this.userCommand}, schemaJson: ${_this.schemaJson}, timeoutSeconds: ${_this.timeoutSeconds})';
}


}

/// @nodoc
abstract mixin class $AgentRequestCopyWith<$Res>  {
  factory $AgentRequestCopyWith(AgentRequest value, $Res Function(AgentRequest) _then) = _$AgentRequestCopyWithImpl;
@useResult
$Res call({
 String systemPrompt, String userCommand, String schemaJson, int timeoutSeconds
});




}
/// @nodoc
class _$AgentRequestCopyWithImpl<$Res>
    implements $AgentRequestCopyWith<$Res> {
  _$AgentRequestCopyWithImpl(this._self, this._then);

  final AgentRequest _self;
  final $Res Function(AgentRequest) _then;

/// Create a copy of AgentRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? systemPrompt = null,Object? userCommand = null,Object? schemaJson = null,Object? timeoutSeconds = null,}) {
  return _then(AgentRequest(
systemPrompt: null == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String,userCommand: null == userCommand ? _self.userCommand : userCommand // ignore: cast_nullable_to_non_nullable
as String,schemaJson: null == schemaJson ? _self.schemaJson : schemaJson // ignore: cast_nullable_to_non_nullable
as String,timeoutSeconds: null == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentRequest].
extension AgentRequestPatterns on AgentRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentRequest value)  $default,){
final _that = this;
switch (_that) {
case _AgentRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentRequest value)?  $default,){
final _that = this;
switch (_that) {
case _AgentRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String systemPrompt,  String userCommand,  String schemaJson,  int timeoutSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentRequest() when $default != null:
return $default(_that.systemPrompt,_that.userCommand,_that.schemaJson,_that.timeoutSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String systemPrompt,  String userCommand,  String schemaJson,  int timeoutSeconds)  $default,) {final _that = this;
switch (_that) {
case _AgentRequest():
return $default(_that.systemPrompt,_that.userCommand,_that.schemaJson,_that.timeoutSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String systemPrompt,  String userCommand,  String schemaJson,  int timeoutSeconds)?  $default,) {final _that = this;
switch (_that) {
case _AgentRequest() when $default != null:
return $default(_that.systemPrompt,_that.userCommand,_that.schemaJson,_that.timeoutSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _AgentRequest implements AgentRequest {
  const _AgentRequest({required this.systemPrompt, required this.userCommand, required this.schemaJson, required this.timeoutSeconds});
  

@override final  String systemPrompt;
@override final  String userCommand;
@override final  String schemaJson;
@override final  int timeoutSeconds;

/// Create a copy of AgentRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentRequestCopyWith<_AgentRequest> get copyWith => __$AgentRequestCopyWithImpl<_AgentRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentRequest&&(identical(other.systemPrompt, systemPrompt) || other.systemPrompt == systemPrompt)&&(identical(other.userCommand, userCommand) || other.userCommand == userCommand)&&(identical(other.schemaJson, schemaJson) || other.schemaJson == schemaJson)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,systemPrompt,userCommand,schemaJson,timeoutSeconds);
}

@override
String toString() {
    return 'AgentRequest(systemPrompt: $systemPrompt, userCommand: $userCommand, schemaJson: $schemaJson, timeoutSeconds: $timeoutSeconds)';
}


}

/// @nodoc
abstract mixin class _$AgentRequestCopyWith<$Res> implements $AgentRequestCopyWith<$Res> {
  factory _$AgentRequestCopyWith(_AgentRequest value, $Res Function(_AgentRequest) _then) = __$AgentRequestCopyWithImpl;
@override @useResult
$Res call({
 String systemPrompt, String userCommand, String schemaJson, int timeoutSeconds
});




}
/// @nodoc
class __$AgentRequestCopyWithImpl<$Res>
    implements _$AgentRequestCopyWith<$Res> {
  __$AgentRequestCopyWithImpl(this._self, this._then);

  final _AgentRequest _self;
  final $Res Function(_AgentRequest) _then;

/// Create a copy of AgentRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? systemPrompt = null,Object? userCommand = null,Object? schemaJson = null,Object? timeoutSeconds = null,}) {
  return _then(_AgentRequest(
systemPrompt: null == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String,userCommand: null == userCommand ? _self.userCommand : userCommand // ignore: cast_nullable_to_non_nullable
as String,schemaJson: null == schemaJson ? _self.schemaJson : schemaJson // ignore: cast_nullable_to_non_nullable
as String,timeoutSeconds: null == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ClarificationNeeded {

 String get question; List<String> get options;
/// Create a copy of ClarificationNeeded
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClarificationNeededCopyWith<ClarificationNeeded> get copyWith => _$ClarificationNeededCopyWithImpl<ClarificationNeeded>(this as ClarificationNeeded, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ClarificationNeeded;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClarificationNeeded&&(identical(other.question, _this.question) || other.question == _this.question)&&const DeepCollectionEquality().equals(other.options, _this.options));
}


@override
int get hashCode {
  final _this = this as ClarificationNeeded;
  return Object.hash(runtimeType,_this.question,const DeepCollectionEquality().hash(_this.options));
}

@override
String toString() {
  final _this = this as ClarificationNeeded;
  return 'ClarificationNeeded(question: ${_this.question}, options: ${_this.options})';
}


}

/// @nodoc
abstract mixin class $ClarificationNeededCopyWith<$Res>  {
  factory $ClarificationNeededCopyWith(ClarificationNeeded value, $Res Function(ClarificationNeeded) _then) = _$ClarificationNeededCopyWithImpl;
@useResult
$Res call({
 String question, List<String> options
});




}
/// @nodoc
class _$ClarificationNeededCopyWithImpl<$Res>
    implements $ClarificationNeededCopyWith<$Res> {
  _$ClarificationNeededCopyWithImpl(this._self, this._then);

  final ClarificationNeeded _self;
  final $Res Function(ClarificationNeeded) _then;

/// Create a copy of ClarificationNeeded
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? question = null,Object? options = null,}) {
  return _then(ClarificationNeeded(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ClarificationNeeded].
extension ClarificationNeededPatterns on ClarificationNeeded {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClarificationNeeded value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClarificationNeeded() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClarificationNeeded value)  $default,){
final _that = this;
switch (_that) {
case _ClarificationNeeded():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClarificationNeeded value)?  $default,){
final _that = this;
switch (_that) {
case _ClarificationNeeded() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String question,  List<String> options)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClarificationNeeded() when $default != null:
return $default(_that.question,_that.options);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String question,  List<String> options)  $default,) {final _that = this;
switch (_that) {
case _ClarificationNeeded():
return $default(_that.question,_that.options);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String question,  List<String> options)?  $default,) {final _that = this;
switch (_that) {
case _ClarificationNeeded() when $default != null:
return $default(_that.question,_that.options);case _:
  return null;

}
}

}

/// @nodoc


class _ClarificationNeeded implements ClarificationNeeded {
  const _ClarificationNeeded({required this.question, required  List<String> options}): _options = options;
  

@override final  String question;
 final  List<String> _options;
@override List<String> get options {
  if (_options is EqualUnmodifiableListView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_options);
}


/// Create a copy of ClarificationNeeded
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClarificationNeededCopyWith<_ClarificationNeeded> get copyWith => __$ClarificationNeededCopyWithImpl<_ClarificationNeeded>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClarificationNeeded&&(identical(other.question, question) || other.question == question)&&const DeepCollectionEquality().equals(other.options, _options));
}


@override
int get hashCode {
    return Object.hash(runtimeType,question,const DeepCollectionEquality().hash(_options));
}

@override
String toString() {
    return 'ClarificationNeeded(question: $question, options: $options)';
}


}

/// @nodoc
abstract mixin class _$ClarificationNeededCopyWith<$Res> implements $ClarificationNeededCopyWith<$Res> {
  factory _$ClarificationNeededCopyWith(_ClarificationNeeded value, $Res Function(_ClarificationNeeded) _then) = __$ClarificationNeededCopyWithImpl;
@override @useResult
$Res call({
 String question, List<String> options
});




}
/// @nodoc
class __$ClarificationNeededCopyWithImpl<$Res>
    implements _$ClarificationNeededCopyWith<$Res> {
  __$ClarificationNeededCopyWithImpl(this._self, this._then);

  final _ClarificationNeeded _self;
  final $Res Function(_ClarificationNeeded) _then;

/// Create a copy of ClarificationNeeded
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? question = null,Object? options = null,}) {
  return _then(_ClarificationNeeded(
question: null == question ? _self.question : question // ignore: cast_nullable_to_non_nullable
as String,options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
