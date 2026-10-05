// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_turn.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AgentToolCall {

 String get id; String get name; Map<String, dynamic> get args;
/// Create a copy of AgentToolCall
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentToolCallCopyWith<AgentToolCall> get copyWith => _$AgentToolCallCopyWithImpl<AgentToolCall>(this as AgentToolCall, _$identity);

  /// Serializes this AgentToolCall to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AgentToolCall;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentToolCall&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.args, _this.args));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AgentToolCall;
  return Object.hash(runtimeType,_this.id,_this.name,const DeepCollectionEquality().hash(_this.args));
}

@override
String toString() {
  final _this = this as AgentToolCall;
  return 'AgentToolCall(id: ${_this.id}, name: ${_this.name}, args: ${_this.args})';
}


}

/// @nodoc
abstract mixin class $AgentToolCallCopyWith<$Res>  {
  factory $AgentToolCallCopyWith(AgentToolCall value, $Res Function(AgentToolCall) _then) = _$AgentToolCallCopyWithImpl;
@useResult
$Res call({
 String id, String name, Map<String, dynamic> args
});




}
/// @nodoc
class _$AgentToolCallCopyWithImpl<$Res>
    implements $AgentToolCallCopyWith<$Res> {
  _$AgentToolCallCopyWithImpl(this._self, this._then);

  final AgentToolCall _self;
  final $Res Function(AgentToolCall) _then;

/// Create a copy of AgentToolCall
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? args = null,}) {
  return _then(AgentToolCall(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentToolCall].
extension AgentToolCallPatterns on AgentToolCall {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentToolCall value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentToolCall() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentToolCall value)  $default,){
final _that = this;
switch (_that) {
case _AgentToolCall():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentToolCall value)?  $default,){
final _that = this;
switch (_that) {
case _AgentToolCall() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  Map<String, dynamic> args)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentToolCall() when $default != null:
return $default(_that.id,_that.name,_that.args);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  Map<String, dynamic> args)  $default,) {final _that = this;
switch (_that) {
case _AgentToolCall():
return $default(_that.id,_that.name,_that.args);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  Map<String, dynamic> args)?  $default,) {final _that = this;
switch (_that) {
case _AgentToolCall() when $default != null:
return $default(_that.id,_that.name,_that.args);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentToolCall implements AgentToolCall {
  const _AgentToolCall({required this.id, required this.name,  Map<String, dynamic> args = const {}}): _args = args;
  factory _AgentToolCall.fromJson(Map<String, dynamic> json) => _$AgentToolCallFromJson(json);

@override final  String id;
@override final  String name;
 final  Map<String, dynamic> _args;
@override@JsonKey() Map<String, dynamic> get args {
  if (_args is EqualUnmodifiableMapView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_args);
}


/// Create a copy of AgentToolCall
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentToolCallCopyWith<_AgentToolCall> get copyWith => __$AgentToolCallCopyWithImpl<_AgentToolCall>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentToolCallToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentToolCall&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.args, _args));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_args));
}

@override
String toString() {
    return 'AgentToolCall(id: $id, name: $name, args: $args)';
}


}

/// @nodoc
abstract mixin class _$AgentToolCallCopyWith<$Res> implements $AgentToolCallCopyWith<$Res> {
  factory _$AgentToolCallCopyWith(_AgentToolCall value, $Res Function(_AgentToolCall) _then) = __$AgentToolCallCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, Map<String, dynamic> args
});




}
/// @nodoc
class __$AgentToolCallCopyWithImpl<$Res>
    implements _$AgentToolCallCopyWith<$Res> {
  __$AgentToolCallCopyWithImpl(this._self, this._then);

  final _AgentToolCall _self;
  final $Res Function(_AgentToolCall) _then;

/// Create a copy of AgentToolCall
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? args = null,}) {
  return _then(_AgentToolCall(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$AgentTurnMessage {

 AgentTurnRole get role; String? get content; List<AgentToolCall> get toolCalls; String? get toolCallId; bool get toolError; String? get toolName;
/// Create a copy of AgentTurnMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentTurnMessageCopyWith<AgentTurnMessage> get copyWith => _$AgentTurnMessageCopyWithImpl<AgentTurnMessage>(this as AgentTurnMessage, _$identity);

  /// Serializes this AgentTurnMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AgentTurnMessage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentTurnMessage&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.content, _this.content) || other.content == _this.content)&&const DeepCollectionEquality().equals(other.toolCalls, _this.toolCalls)&&(identical(other.toolCallId, _this.toolCallId) || other.toolCallId == _this.toolCallId)&&(identical(other.toolError, _this.toolError) || other.toolError == _this.toolError)&&(identical(other.toolName, _this.toolName) || other.toolName == _this.toolName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AgentTurnMessage;
  return Object.hash(runtimeType,_this.role,_this.content,const DeepCollectionEquality().hash(_this.toolCalls),_this.toolCallId,_this.toolError,_this.toolName);
}

@override
String toString() {
  final _this = this as AgentTurnMessage;
  return 'AgentTurnMessage(role: ${_this.role}, content: ${_this.content}, toolCalls: ${_this.toolCalls}, toolCallId: ${_this.toolCallId}, toolError: ${_this.toolError}, toolName: ${_this.toolName})';
}


}

/// @nodoc
abstract mixin class $AgentTurnMessageCopyWith<$Res>  {
  factory $AgentTurnMessageCopyWith(AgentTurnMessage value, $Res Function(AgentTurnMessage) _then) = _$AgentTurnMessageCopyWithImpl;
@useResult
$Res call({
 AgentTurnRole role, String? content, List<AgentToolCall> toolCalls, String? toolCallId, bool toolError, String? toolName
});




}
/// @nodoc
class _$AgentTurnMessageCopyWithImpl<$Res>
    implements $AgentTurnMessageCopyWith<$Res> {
  _$AgentTurnMessageCopyWithImpl(this._self, this._then);

  final AgentTurnMessage _self;
  final $Res Function(AgentTurnMessage) _then;

/// Create a copy of AgentTurnMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,Object? content = freezed,Object? toolCalls = null,Object? toolCallId = freezed,Object? toolError = null,Object? toolName = freezed,}) {
  return _then(AgentTurnMessage(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AgentTurnRole,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,toolCalls: null == toolCalls ? _self.toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as List<AgentToolCall>,toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,toolError: null == toolError ? _self.toolError : toolError // ignore: cast_nullable_to_non_nullable
as bool,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentTurnMessage].
extension AgentTurnMessagePatterns on AgentTurnMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentTurnMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentTurnMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentTurnMessage value)  $default,){
final _that = this;
switch (_that) {
case _AgentTurnMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentTurnMessage value)?  $default,){
final _that = this;
switch (_that) {
case _AgentTurnMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AgentTurnRole role,  String? content,  List<AgentToolCall> toolCalls,  String? toolCallId,  bool toolError,  String? toolName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentTurnMessage() when $default != null:
return $default(_that.role,_that.content,_that.toolCalls,_that.toolCallId,_that.toolError,_that.toolName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AgentTurnRole role,  String? content,  List<AgentToolCall> toolCalls,  String? toolCallId,  bool toolError,  String? toolName)  $default,) {final _that = this;
switch (_that) {
case _AgentTurnMessage():
return $default(_that.role,_that.content,_that.toolCalls,_that.toolCallId,_that.toolError,_that.toolName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AgentTurnRole role,  String? content,  List<AgentToolCall> toolCalls,  String? toolCallId,  bool toolError,  String? toolName)?  $default,) {final _that = this;
switch (_that) {
case _AgentTurnMessage() when $default != null:
return $default(_that.role,_that.content,_that.toolCalls,_that.toolCallId,_that.toolError,_that.toolName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentTurnMessage implements AgentTurnMessage {
  const _AgentTurnMessage({required this.role, this.content,  List<AgentToolCall> toolCalls = const [], this.toolCallId, this.toolError = false, this.toolName}): _toolCalls = toolCalls;
  factory _AgentTurnMessage.fromJson(Map<String, dynamic> json) => _$AgentTurnMessageFromJson(json);

@override final  AgentTurnRole role;
@override final  String? content;
 final  List<AgentToolCall> _toolCalls;
@override@JsonKey() List<AgentToolCall> get toolCalls {
  if (_toolCalls is EqualUnmodifiableListView) return _toolCalls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_toolCalls);
}

@override final  String? toolCallId;
@override@JsonKey() final  bool toolError;
@override final  String? toolName;

/// Create a copy of AgentTurnMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentTurnMessageCopyWith<_AgentTurnMessage> get copyWith => __$AgentTurnMessageCopyWithImpl<_AgentTurnMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentTurnMessageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentTurnMessage&&(identical(other.role, role) || other.role == role)&&(identical(other.content, content) || other.content == content)&&const DeepCollectionEquality().equals(other.toolCalls, _toolCalls)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolError, toolError) || other.toolError == toolError)&&(identical(other.toolName, toolName) || other.toolName == toolName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,role,content,const DeepCollectionEquality().hash(_toolCalls),toolCallId,toolError,toolName);
}

@override
String toString() {
    return 'AgentTurnMessage(role: $role, content: $content, toolCalls: $toolCalls, toolCallId: $toolCallId, toolError: $toolError, toolName: $toolName)';
}


}

/// @nodoc
abstract mixin class _$AgentTurnMessageCopyWith<$Res> implements $AgentTurnMessageCopyWith<$Res> {
  factory _$AgentTurnMessageCopyWith(_AgentTurnMessage value, $Res Function(_AgentTurnMessage) _then) = __$AgentTurnMessageCopyWithImpl;
@override @useResult
$Res call({
 AgentTurnRole role, String? content, List<AgentToolCall> toolCalls, String? toolCallId, bool toolError, String? toolName
});




}
/// @nodoc
class __$AgentTurnMessageCopyWithImpl<$Res>
    implements _$AgentTurnMessageCopyWith<$Res> {
  __$AgentTurnMessageCopyWithImpl(this._self, this._then);

  final _AgentTurnMessage _self;
  final $Res Function(_AgentTurnMessage) _then;

/// Create a copy of AgentTurnMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,Object? content = freezed,Object? toolCalls = null,Object? toolCallId = freezed,Object? toolError = null,Object? toolName = freezed,}) {
  return _then(_AgentTurnMessage(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AgentTurnRole,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,toolCalls: null == toolCalls ? _self._toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as List<AgentToolCall>,toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,toolError: null == toolError ? _self.toolError : toolError // ignore: cast_nullable_to_non_nullable
as bool,toolName: freezed == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AgentTurnRequest {

 String get systemPrompt; String get userContent; List<ToolDefinition> get tools; List<AgentTurnMessage> get history; int get timeoutSeconds; double get temperature;
/// Create a copy of AgentTurnRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentTurnRequestCopyWith<AgentTurnRequest> get copyWith => _$AgentTurnRequestCopyWithImpl<AgentTurnRequest>(this as AgentTurnRequest, _$identity);

  /// Serializes this AgentTurnRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AgentTurnRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentTurnRequest&&(identical(other.systemPrompt, _this.systemPrompt) || other.systemPrompt == _this.systemPrompt)&&(identical(other.userContent, _this.userContent) || other.userContent == _this.userContent)&&const DeepCollectionEquality().equals(other.tools, _this.tools)&&const DeepCollectionEquality().equals(other.history, _this.history)&&(identical(other.timeoutSeconds, _this.timeoutSeconds) || other.timeoutSeconds == _this.timeoutSeconds)&&(identical(other.temperature, _this.temperature) || other.temperature == _this.temperature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AgentTurnRequest;
  return Object.hash(runtimeType,_this.systemPrompt,_this.userContent,const DeepCollectionEquality().hash(_this.tools),const DeepCollectionEquality().hash(_this.history),_this.timeoutSeconds,_this.temperature);
}

@override
String toString() {
  final _this = this as AgentTurnRequest;
  return 'AgentTurnRequest(systemPrompt: ${_this.systemPrompt}, userContent: ${_this.userContent}, tools: ${_this.tools}, history: ${_this.history}, timeoutSeconds: ${_this.timeoutSeconds}, temperature: ${_this.temperature})';
}


}

/// @nodoc
abstract mixin class $AgentTurnRequestCopyWith<$Res>  {
  factory $AgentTurnRequestCopyWith(AgentTurnRequest value, $Res Function(AgentTurnRequest) _then) = _$AgentTurnRequestCopyWithImpl;
@useResult
$Res call({
 String systemPrompt, String userContent, List<ToolDefinition> tools, List<AgentTurnMessage> history, int timeoutSeconds, double temperature
});




}
/// @nodoc
class _$AgentTurnRequestCopyWithImpl<$Res>
    implements $AgentTurnRequestCopyWith<$Res> {
  _$AgentTurnRequestCopyWithImpl(this._self, this._then);

  final AgentTurnRequest _self;
  final $Res Function(AgentTurnRequest) _then;

/// Create a copy of AgentTurnRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? systemPrompt = null,Object? userContent = null,Object? tools = null,Object? history = null,Object? timeoutSeconds = null,Object? temperature = null,}) {
  return _then(AgentTurnRequest(
systemPrompt: null == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String,userContent: null == userContent ? _self.userContent : userContent // ignore: cast_nullable_to_non_nullable
as String,tools: null == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<ToolDefinition>,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<AgentTurnMessage>,timeoutSeconds: null == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentTurnRequest].
extension AgentTurnRequestPatterns on AgentTurnRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentTurnRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentTurnRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentTurnRequest value)  $default,){
final _that = this;
switch (_that) {
case _AgentTurnRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentTurnRequest value)?  $default,){
final _that = this;
switch (_that) {
case _AgentTurnRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String systemPrompt,  String userContent,  List<ToolDefinition> tools,  List<AgentTurnMessage> history,  int timeoutSeconds,  double temperature)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentTurnRequest() when $default != null:
return $default(_that.systemPrompt,_that.userContent,_that.tools,_that.history,_that.timeoutSeconds,_that.temperature);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String systemPrompt,  String userContent,  List<ToolDefinition> tools,  List<AgentTurnMessage> history,  int timeoutSeconds,  double temperature)  $default,) {final _that = this;
switch (_that) {
case _AgentTurnRequest():
return $default(_that.systemPrompt,_that.userContent,_that.tools,_that.history,_that.timeoutSeconds,_that.temperature);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String systemPrompt,  String userContent,  List<ToolDefinition> tools,  List<AgentTurnMessage> history,  int timeoutSeconds,  double temperature)?  $default,) {final _that = this;
switch (_that) {
case _AgentTurnRequest() when $default != null:
return $default(_that.systemPrompt,_that.userContent,_that.tools,_that.history,_that.timeoutSeconds,_that.temperature);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentTurnRequest implements AgentTurnRequest {
  const _AgentTurnRequest({required this.systemPrompt, required this.userContent,  List<ToolDefinition> tools = const [],  List<AgentTurnMessage> history = const [], this.timeoutSeconds = 60, this.temperature = 0.1}): _tools = tools,_history = history;
  factory _AgentTurnRequest.fromJson(Map<String, dynamic> json) => _$AgentTurnRequestFromJson(json);

@override final  String systemPrompt;
@override final  String userContent;
 final  List<ToolDefinition> _tools;
@override@JsonKey() List<ToolDefinition> get tools {
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tools);
}

 final  List<AgentTurnMessage> _history;
@override@JsonKey() List<AgentTurnMessage> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}

@override@JsonKey() final  int timeoutSeconds;
@override@JsonKey() final  double temperature;

/// Create a copy of AgentTurnRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentTurnRequestCopyWith<_AgentTurnRequest> get copyWith => __$AgentTurnRequestCopyWithImpl<_AgentTurnRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentTurnRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentTurnRequest&&(identical(other.systemPrompt, systemPrompt) || other.systemPrompt == systemPrompt)&&(identical(other.userContent, userContent) || other.userContent == userContent)&&const DeepCollectionEquality().equals(other.tools, _tools)&&const DeepCollectionEquality().equals(other.history, _history)&&(identical(other.timeoutSeconds, timeoutSeconds) || other.timeoutSeconds == timeoutSeconds)&&(identical(other.temperature, temperature) || other.temperature == temperature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,systemPrompt,userContent,const DeepCollectionEquality().hash(_tools),const DeepCollectionEquality().hash(_history),timeoutSeconds,temperature);
}

@override
String toString() {
    return 'AgentTurnRequest(systemPrompt: $systemPrompt, userContent: $userContent, tools: $tools, history: $history, timeoutSeconds: $timeoutSeconds, temperature: $temperature)';
}


}

/// @nodoc
abstract mixin class _$AgentTurnRequestCopyWith<$Res> implements $AgentTurnRequestCopyWith<$Res> {
  factory _$AgentTurnRequestCopyWith(_AgentTurnRequest value, $Res Function(_AgentTurnRequest) _then) = __$AgentTurnRequestCopyWithImpl;
@override @useResult
$Res call({
 String systemPrompt, String userContent, List<ToolDefinition> tools, List<AgentTurnMessage> history, int timeoutSeconds, double temperature
});




}
/// @nodoc
class __$AgentTurnRequestCopyWithImpl<$Res>
    implements _$AgentTurnRequestCopyWith<$Res> {
  __$AgentTurnRequestCopyWithImpl(this._self, this._then);

  final _AgentTurnRequest _self;
  final $Res Function(_AgentTurnRequest) _then;

/// Create a copy of AgentTurnRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? systemPrompt = null,Object? userContent = null,Object? tools = null,Object? history = null,Object? timeoutSeconds = null,Object? temperature = null,}) {
  return _then(_AgentTurnRequest(
systemPrompt: null == systemPrompt ? _self.systemPrompt : systemPrompt // ignore: cast_nullable_to_non_nullable
as String,userContent: null == userContent ? _self.userContent : userContent // ignore: cast_nullable_to_non_nullable
as String,tools: null == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<ToolDefinition>,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<AgentTurnMessage>,timeoutSeconds: null == timeoutSeconds ? _self.timeoutSeconds : timeoutSeconds // ignore: cast_nullable_to_non_nullable
as int,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$AgentToolCallRecord {

 String get id; String get name; Map<String, dynamic> get args; bool get success; String get summary; int get durationMs;
/// Create a copy of AgentToolCallRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentToolCallRecordCopyWith<AgentToolCallRecord> get copyWith => _$AgentToolCallRecordCopyWithImpl<AgentToolCallRecord>(this as AgentToolCallRecord, _$identity);

  /// Serializes this AgentToolCallRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AgentToolCallRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentToolCallRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.args, _this.args)&&(identical(other.success, _this.success) || other.success == _this.success)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AgentToolCallRecord;
  return Object.hash(runtimeType,_this.id,_this.name,const DeepCollectionEquality().hash(_this.args),_this.success,_this.summary,_this.durationMs);
}

@override
String toString() {
  final _this = this as AgentToolCallRecord;
  return 'AgentToolCallRecord(id: ${_this.id}, name: ${_this.name}, args: ${_this.args}, success: ${_this.success}, summary: ${_this.summary}, durationMs: ${_this.durationMs})';
}


}

/// @nodoc
abstract mixin class $AgentToolCallRecordCopyWith<$Res>  {
  factory $AgentToolCallRecordCopyWith(AgentToolCallRecord value, $Res Function(AgentToolCallRecord) _then) = _$AgentToolCallRecordCopyWithImpl;
@useResult
$Res call({
 String id, String name, Map<String, dynamic> args, bool success, String summary, int durationMs
});




}
/// @nodoc
class _$AgentToolCallRecordCopyWithImpl<$Res>
    implements $AgentToolCallRecordCopyWith<$Res> {
  _$AgentToolCallRecordCopyWithImpl(this._self, this._then);

  final AgentToolCallRecord _self;
  final $Res Function(AgentToolCallRecord) _then;

/// Create a copy of AgentToolCallRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? args = null,Object? success = null,Object? summary = null,Object? durationMs = null,}) {
  return _then(AgentToolCallRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentToolCallRecord].
extension AgentToolCallRecordPatterns on AgentToolCallRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentToolCallRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentToolCallRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentToolCallRecord value)  $default,){
final _that = this;
switch (_that) {
case _AgentToolCallRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentToolCallRecord value)?  $default,){
final _that = this;
switch (_that) {
case _AgentToolCallRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  Map<String, dynamic> args,  bool success,  String summary,  int durationMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentToolCallRecord() when $default != null:
return $default(_that.id,_that.name,_that.args,_that.success,_that.summary,_that.durationMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  Map<String, dynamic> args,  bool success,  String summary,  int durationMs)  $default,) {final _that = this;
switch (_that) {
case _AgentToolCallRecord():
return $default(_that.id,_that.name,_that.args,_that.success,_that.summary,_that.durationMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  Map<String, dynamic> args,  bool success,  String summary,  int durationMs)?  $default,) {final _that = this;
switch (_that) {
case _AgentToolCallRecord() when $default != null:
return $default(_that.id,_that.name,_that.args,_that.success,_that.summary,_that.durationMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentToolCallRecord implements AgentToolCallRecord {
  const _AgentToolCallRecord({required this.id, required this.name,  Map<String, dynamic> args = const {}, required this.success, this.summary = '', this.durationMs = 0}): _args = args;
  factory _AgentToolCallRecord.fromJson(Map<String, dynamic> json) => _$AgentToolCallRecordFromJson(json);

@override final  String id;
@override final  String name;
 final  Map<String, dynamic> _args;
@override@JsonKey() Map<String, dynamic> get args {
  if (_args is EqualUnmodifiableMapView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_args);
}

@override final  bool success;
@override@JsonKey() final  String summary;
@override@JsonKey() final  int durationMs;

/// Create a copy of AgentToolCallRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentToolCallRecordCopyWith<_AgentToolCallRecord> get copyWith => __$AgentToolCallRecordCopyWithImpl<_AgentToolCallRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentToolCallRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentToolCallRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.args, _args)&&(identical(other.success, success) || other.success == success)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_args),success,summary,durationMs);
}

@override
String toString() {
    return 'AgentToolCallRecord(id: $id, name: $name, args: $args, success: $success, summary: $summary, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class _$AgentToolCallRecordCopyWith<$Res> implements $AgentToolCallRecordCopyWith<$Res> {
  factory _$AgentToolCallRecordCopyWith(_AgentToolCallRecord value, $Res Function(_AgentToolCallRecord) _then) = __$AgentToolCallRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, Map<String, dynamic> args, bool success, String summary, int durationMs
});




}
/// @nodoc
class __$AgentToolCallRecordCopyWithImpl<$Res>
    implements _$AgentToolCallRecordCopyWith<$Res> {
  __$AgentToolCallRecordCopyWithImpl(this._self, this._then);

  final _AgentToolCallRecord _self;
  final $Res Function(_AgentToolCallRecord) _then;

/// Create a copy of AgentToolCallRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? args = null,Object? success = null,Object? summary = null,Object? durationMs = null,}) {
  return _then(_AgentToolCallRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AgentTurnResult {

 String get text; List<AgentToolCall> get toolCalls; List<AgentToolCallRecord> get records; AgentTurnStopReason get stopReason;
/// Create a copy of AgentTurnResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentTurnResultCopyWith<AgentTurnResult> get copyWith => _$AgentTurnResultCopyWithImpl<AgentTurnResult>(this as AgentTurnResult, _$identity);

  /// Serializes this AgentTurnResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AgentTurnResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentTurnResult&&(identical(other.text, _this.text) || other.text == _this.text)&&const DeepCollectionEquality().equals(other.toolCalls, _this.toolCalls)&&const DeepCollectionEquality().equals(other.records, _this.records)&&(identical(other.stopReason, _this.stopReason) || other.stopReason == _this.stopReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AgentTurnResult;
  return Object.hash(runtimeType,_this.text,const DeepCollectionEquality().hash(_this.toolCalls),const DeepCollectionEquality().hash(_this.records),_this.stopReason);
}

@override
String toString() {
  final _this = this as AgentTurnResult;
  return 'AgentTurnResult(text: ${_this.text}, toolCalls: ${_this.toolCalls}, records: ${_this.records}, stopReason: ${_this.stopReason})';
}


}

/// @nodoc
abstract mixin class $AgentTurnResultCopyWith<$Res>  {
  factory $AgentTurnResultCopyWith(AgentTurnResult value, $Res Function(AgentTurnResult) _then) = _$AgentTurnResultCopyWithImpl;
@useResult
$Res call({
 String text, List<AgentToolCall> toolCalls, List<AgentToolCallRecord> records, AgentTurnStopReason stopReason
});




}
/// @nodoc
class _$AgentTurnResultCopyWithImpl<$Res>
    implements $AgentTurnResultCopyWith<$Res> {
  _$AgentTurnResultCopyWithImpl(this._self, this._then);

  final AgentTurnResult _self;
  final $Res Function(AgentTurnResult) _then;

/// Create a copy of AgentTurnResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? toolCalls = null,Object? records = null,Object? stopReason = null,}) {
  return _then(AgentTurnResult(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,toolCalls: null == toolCalls ? _self.toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as List<AgentToolCall>,records: null == records ? _self.records : records // ignore: cast_nullable_to_non_nullable
as List<AgentToolCallRecord>,stopReason: null == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as AgentTurnStopReason,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentTurnResult].
extension AgentTurnResultPatterns on AgentTurnResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentTurnResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentTurnResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentTurnResult value)  $default,){
final _that = this;
switch (_that) {
case _AgentTurnResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentTurnResult value)?  $default,){
final _that = this;
switch (_that) {
case _AgentTurnResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  List<AgentToolCall> toolCalls,  List<AgentToolCallRecord> records,  AgentTurnStopReason stopReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentTurnResult() when $default != null:
return $default(_that.text,_that.toolCalls,_that.records,_that.stopReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  List<AgentToolCall> toolCalls,  List<AgentToolCallRecord> records,  AgentTurnStopReason stopReason)  $default,) {final _that = this;
switch (_that) {
case _AgentTurnResult():
return $default(_that.text,_that.toolCalls,_that.records,_that.stopReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  List<AgentToolCall> toolCalls,  List<AgentToolCallRecord> records,  AgentTurnStopReason stopReason)?  $default,) {final _that = this;
switch (_that) {
case _AgentTurnResult() when $default != null:
return $default(_that.text,_that.toolCalls,_that.records,_that.stopReason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AgentTurnResult implements AgentTurnResult {
  const _AgentTurnResult({this.text = '',  List<AgentToolCall> toolCalls = const [],  List<AgentToolCallRecord> records = const [], this.stopReason = AgentTurnStopReason.stop}): _toolCalls = toolCalls,_records = records;
  factory _AgentTurnResult.fromJson(Map<String, dynamic> json) => _$AgentTurnResultFromJson(json);

@override@JsonKey() final  String text;
 final  List<AgentToolCall> _toolCalls;
@override@JsonKey() List<AgentToolCall> get toolCalls {
  if (_toolCalls is EqualUnmodifiableListView) return _toolCalls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_toolCalls);
}

 final  List<AgentToolCallRecord> _records;
@override@JsonKey() List<AgentToolCallRecord> get records {
  if (_records is EqualUnmodifiableListView) return _records;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_records);
}

@override@JsonKey() final  AgentTurnStopReason stopReason;

/// Create a copy of AgentTurnResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentTurnResultCopyWith<_AgentTurnResult> get copyWith => __$AgentTurnResultCopyWithImpl<_AgentTurnResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AgentTurnResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentTurnResult&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.toolCalls, _toolCalls)&&const DeepCollectionEquality().equals(other.records, _records)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text,const DeepCollectionEquality().hash(_toolCalls),const DeepCollectionEquality().hash(_records),stopReason);
}

@override
String toString() {
    return 'AgentTurnResult(text: $text, toolCalls: $toolCalls, records: $records, stopReason: $stopReason)';
}


}

/// @nodoc
abstract mixin class _$AgentTurnResultCopyWith<$Res> implements $AgentTurnResultCopyWith<$Res> {
  factory _$AgentTurnResultCopyWith(_AgentTurnResult value, $Res Function(_AgentTurnResult) _then) = __$AgentTurnResultCopyWithImpl;
@override @useResult
$Res call({
 String text, List<AgentToolCall> toolCalls, List<AgentToolCallRecord> records, AgentTurnStopReason stopReason
});




}
/// @nodoc
class __$AgentTurnResultCopyWithImpl<$Res>
    implements _$AgentTurnResultCopyWith<$Res> {
  __$AgentTurnResultCopyWithImpl(this._self, this._then);

  final _AgentTurnResult _self;
  final $Res Function(_AgentTurnResult) _then;

/// Create a copy of AgentTurnResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? toolCalls = null,Object? records = null,Object? stopReason = null,}) {
  return _then(_AgentTurnResult(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,toolCalls: null == toolCalls ? _self._toolCalls : toolCalls // ignore: cast_nullable_to_non_nullable
as List<AgentToolCall>,records: null == records ? _self._records : records // ignore: cast_nullable_to_non_nullable
as List<AgentToolCallRecord>,stopReason: null == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as AgentTurnStopReason,
  ));
}


}

// dart format on
