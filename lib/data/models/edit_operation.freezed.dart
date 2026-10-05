// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'edit_operation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EditOperation {

 String get id; EditOperationType get type; List<String> get targetClipIds; Map<String, dynamic> get params; DateTime get createdAt; String get sourceChatMessageId; OperationStatus get status; String? get ffmpegCommand;
/// Create a copy of EditOperation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EditOperationCopyWith<EditOperation> get copyWith => _$EditOperationCopyWithImpl<EditOperation>(this as EditOperation, _$identity);

  /// Serializes this EditOperation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EditOperation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EditOperation&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&const DeepCollectionEquality().equals(other.targetClipIds, _this.targetClipIds)&&const DeepCollectionEquality().equals(other.params, _this.params)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.sourceChatMessageId, _this.sourceChatMessageId) || other.sourceChatMessageId == _this.sourceChatMessageId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.ffmpegCommand, _this.ffmpegCommand) || other.ffmpegCommand == _this.ffmpegCommand));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EditOperation;
  return Object.hash(runtimeType,_this.id,_this.type,const DeepCollectionEquality().hash(_this.targetClipIds),const DeepCollectionEquality().hash(_this.params),_this.createdAt,_this.sourceChatMessageId,_this.status,_this.ffmpegCommand);
}

@override
String toString() {
  final _this = this as EditOperation;
  return 'EditOperation(id: ${_this.id}, type: ${_this.type}, targetClipIds: ${_this.targetClipIds}, params: ${_this.params}, createdAt: ${_this.createdAt}, sourceChatMessageId: ${_this.sourceChatMessageId}, status: ${_this.status}, ffmpegCommand: ${_this.ffmpegCommand})';
}


}

/// @nodoc
abstract mixin class $EditOperationCopyWith<$Res>  {
  factory $EditOperationCopyWith(EditOperation value, $Res Function(EditOperation) _then) = _$EditOperationCopyWithImpl;
@useResult
$Res call({
 String id, EditOperationType type, List<String> targetClipIds, Map<String, dynamic> params, DateTime createdAt, String sourceChatMessageId, OperationStatus status, String? ffmpegCommand
});




}
/// @nodoc
class _$EditOperationCopyWithImpl<$Res>
    implements $EditOperationCopyWith<$Res> {
  _$EditOperationCopyWithImpl(this._self, this._then);

  final EditOperation _self;
  final $Res Function(EditOperation) _then;

/// Create a copy of EditOperation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? targetClipIds = null,Object? params = null,Object? createdAt = null,Object? sourceChatMessageId = null,Object? status = null,Object? ffmpegCommand = freezed,}) {
  return _then(EditOperation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as EditOperationType,targetClipIds: null == targetClipIds ? _self.targetClipIds : targetClipIds // ignore: cast_nullable_to_non_nullable
as List<String>,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,sourceChatMessageId: null == sourceChatMessageId ? _self.sourceChatMessageId : sourceChatMessageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OperationStatus,ffmpegCommand: freezed == ffmpegCommand ? _self.ffmpegCommand : ffmpegCommand // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EditOperation].
extension EditOperationPatterns on EditOperation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EditOperation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EditOperation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EditOperation value)  $default,){
final _that = this;
switch (_that) {
case _EditOperation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EditOperation value)?  $default,){
final _that = this;
switch (_that) {
case _EditOperation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  EditOperationType type,  List<String> targetClipIds,  Map<String, dynamic> params,  DateTime createdAt,  String sourceChatMessageId,  OperationStatus status,  String? ffmpegCommand)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EditOperation() when $default != null:
return $default(_that.id,_that.type,_that.targetClipIds,_that.params,_that.createdAt,_that.sourceChatMessageId,_that.status,_that.ffmpegCommand);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  EditOperationType type,  List<String> targetClipIds,  Map<String, dynamic> params,  DateTime createdAt,  String sourceChatMessageId,  OperationStatus status,  String? ffmpegCommand)  $default,) {final _that = this;
switch (_that) {
case _EditOperation():
return $default(_that.id,_that.type,_that.targetClipIds,_that.params,_that.createdAt,_that.sourceChatMessageId,_that.status,_that.ffmpegCommand);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  EditOperationType type,  List<String> targetClipIds,  Map<String, dynamic> params,  DateTime createdAt,  String sourceChatMessageId,  OperationStatus status,  String? ffmpegCommand)?  $default,) {final _that = this;
switch (_that) {
case _EditOperation() when $default != null:
return $default(_that.id,_that.type,_that.targetClipIds,_that.params,_that.createdAt,_that.sourceChatMessageId,_that.status,_that.ffmpegCommand);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EditOperation implements EditOperation {
  const _EditOperation({required this.id, required this.type,  List<String> targetClipIds = const [],  Map<String, dynamic> params = const {}, required this.createdAt, this.sourceChatMessageId = '', this.status = OperationStatus.applied, this.ffmpegCommand}): _targetClipIds = targetClipIds,_params = params;
  factory _EditOperation.fromJson(Map<String, dynamic> json) => _$EditOperationFromJson(json);

@override final  String id;
@override final  EditOperationType type;
 final  List<String> _targetClipIds;
@override@JsonKey() List<String> get targetClipIds {
  if (_targetClipIds is EqualUnmodifiableListView) return _targetClipIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_targetClipIds);
}

 final  Map<String, dynamic> _params;
@override@JsonKey() Map<String, dynamic> get params {
  if (_params is EqualUnmodifiableMapView) return _params;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_params);
}

@override final  DateTime createdAt;
@override@JsonKey() final  String sourceChatMessageId;
@override@JsonKey() final  OperationStatus status;
@override final  String? ffmpegCommand;

/// Create a copy of EditOperation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EditOperationCopyWith<_EditOperation> get copyWith => __$EditOperationCopyWithImpl<_EditOperation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EditOperationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EditOperation&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.targetClipIds, _targetClipIds)&&const DeepCollectionEquality().equals(other.params, _params)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.sourceChatMessageId, sourceChatMessageId) || other.sourceChatMessageId == sourceChatMessageId)&&(identical(other.status, status) || other.status == status)&&(identical(other.ffmpegCommand, ffmpegCommand) || other.ffmpegCommand == ffmpegCommand));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,type,const DeepCollectionEquality().hash(_targetClipIds),const DeepCollectionEquality().hash(_params),createdAt,sourceChatMessageId,status,ffmpegCommand);
}

@override
String toString() {
    return 'EditOperation(id: $id, type: $type, targetClipIds: $targetClipIds, params: $params, createdAt: $createdAt, sourceChatMessageId: $sourceChatMessageId, status: $status, ffmpegCommand: $ffmpegCommand)';
}


}

/// @nodoc
abstract mixin class _$EditOperationCopyWith<$Res> implements $EditOperationCopyWith<$Res> {
  factory _$EditOperationCopyWith(_EditOperation value, $Res Function(_EditOperation) _then) = __$EditOperationCopyWithImpl;
@override @useResult
$Res call({
 String id, EditOperationType type, List<String> targetClipIds, Map<String, dynamic> params, DateTime createdAt, String sourceChatMessageId, OperationStatus status, String? ffmpegCommand
});




}
/// @nodoc
class __$EditOperationCopyWithImpl<$Res>
    implements _$EditOperationCopyWith<$Res> {
  __$EditOperationCopyWithImpl(this._self, this._then);

  final _EditOperation _self;
  final $Res Function(_EditOperation) _then;

/// Create a copy of EditOperation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? targetClipIds = null,Object? params = null,Object? createdAt = null,Object? sourceChatMessageId = null,Object? status = null,Object? ffmpegCommand = freezed,}) {
  return _then(_EditOperation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as EditOperationType,targetClipIds: null == targetClipIds ? _self._targetClipIds : targetClipIds // ignore: cast_nullable_to_non_nullable
as List<String>,params: null == params ? _self._params : params // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,sourceChatMessageId: null == sourceChatMessageId ? _self.sourceChatMessageId : sourceChatMessageId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OperationStatus,ffmpegCommand: freezed == ffmpegCommand ? _self.ffmpegCommand : ffmpegCommand // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
