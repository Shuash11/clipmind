// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agent_turn.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AgentToolCall _$AgentToolCallFromJson(Map<String, dynamic> json) {
  return _AgentToolCall.fromJson(json);
}

/// @nodoc
mixin _$AgentToolCall {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  Map<String, dynamic> get args => throw _privateConstructorUsedError;

  /// Serializes this AgentToolCall to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgentToolCall
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgentToolCallCopyWith<AgentToolCall> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentToolCallCopyWith<$Res> {
  factory $AgentToolCallCopyWith(
    AgentToolCall value,
    $Res Function(AgentToolCall) then,
  ) = _$AgentToolCallCopyWithImpl<$Res, AgentToolCall>;
  @useResult
  $Res call({String id, String name, Map<String, dynamic> args});
}

/// @nodoc
class _$AgentToolCallCopyWithImpl<$Res, $Val extends AgentToolCall>
    implements $AgentToolCallCopyWith<$Res> {
  _$AgentToolCallCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentToolCall
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? name = null, Object? args = null}) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            args: null == args
                ? _value.args
                : args // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AgentToolCallImplCopyWith<$Res>
    implements $AgentToolCallCopyWith<$Res> {
  factory _$$AgentToolCallImplCopyWith(
    _$AgentToolCallImpl value,
    $Res Function(_$AgentToolCallImpl) then,
  ) = __$$AgentToolCallImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String name, Map<String, dynamic> args});
}

/// @nodoc
class __$$AgentToolCallImplCopyWithImpl<$Res>
    extends _$AgentToolCallCopyWithImpl<$Res, _$AgentToolCallImpl>
    implements _$$AgentToolCallImplCopyWith<$Res> {
  __$$AgentToolCallImplCopyWithImpl(
    _$AgentToolCallImpl _value,
    $Res Function(_$AgentToolCallImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgentToolCall
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? name = null, Object? args = null}) {
    return _then(
      _$AgentToolCallImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        args: null == args
            ? _value._args
            : args // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AgentToolCallImpl implements _AgentToolCall {
  const _$AgentToolCallImpl({
    required this.id,
    required this.name,
    final Map<String, dynamic> args = const {},
  }) : _args = args;

  factory _$AgentToolCallImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentToolCallImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final Map<String, dynamic> _args;
  @override
  @JsonKey()
  Map<String, dynamic> get args {
    if (_args is EqualUnmodifiableMapView) return _args;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_args);
  }

  @override
  String toString() {
    return 'AgentToolCall(id: $id, name: $name, args: $args)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentToolCallImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._args, _args));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    const DeepCollectionEquality().hash(_args),
  );

  /// Create a copy of AgentToolCall
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentToolCallImplCopyWith<_$AgentToolCallImpl> get copyWith =>
      __$$AgentToolCallImplCopyWithImpl<_$AgentToolCallImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentToolCallImplToJson(this);
  }
}

abstract class _AgentToolCall implements AgentToolCall {
  const factory _AgentToolCall({
    required final String id,
    required final String name,
    final Map<String, dynamic> args,
  }) = _$AgentToolCallImpl;

  factory _AgentToolCall.fromJson(Map<String, dynamic> json) =
      _$AgentToolCallImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  Map<String, dynamic> get args;

  /// Create a copy of AgentToolCall
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentToolCallImplCopyWith<_$AgentToolCallImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AgentTurnMessage _$AgentTurnMessageFromJson(Map<String, dynamic> json) {
  return _AgentTurnMessage.fromJson(json);
}

/// @nodoc
mixin _$AgentTurnMessage {
  AgentTurnRole get role => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  List<AgentToolCall> get toolCalls => throw _privateConstructorUsedError;
  String? get toolCallId => throw _privateConstructorUsedError;
  bool get toolError => throw _privateConstructorUsedError;

  /// Serializes this AgentTurnMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgentTurnMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgentTurnMessageCopyWith<AgentTurnMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentTurnMessageCopyWith<$Res> {
  factory $AgentTurnMessageCopyWith(
    AgentTurnMessage value,
    $Res Function(AgentTurnMessage) then,
  ) = _$AgentTurnMessageCopyWithImpl<$Res, AgentTurnMessage>;
  @useResult
  $Res call({
    AgentTurnRole role,
    String? content,
    List<AgentToolCall> toolCalls,
    String? toolCallId,
    bool toolError,
  });
}

/// @nodoc
class _$AgentTurnMessageCopyWithImpl<$Res, $Val extends AgentTurnMessage>
    implements $AgentTurnMessageCopyWith<$Res> {
  _$AgentTurnMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentTurnMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? role = null,
    Object? content = freezed,
    Object? toolCalls = null,
    Object? toolCallId = freezed,
    Object? toolError = null,
  }) {
    return _then(
      _value.copyWith(
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as AgentTurnRole,
            content: freezed == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String?,
            toolCalls: null == toolCalls
                ? _value.toolCalls
                : toolCalls // ignore: cast_nullable_to_non_nullable
                      as List<AgentToolCall>,
            toolCallId: freezed == toolCallId
                ? _value.toolCallId
                : toolCallId // ignore: cast_nullable_to_non_nullable
                      as String?,
            toolError: null == toolError
                ? _value.toolError
                : toolError // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AgentTurnMessageImplCopyWith<$Res>
    implements $AgentTurnMessageCopyWith<$Res> {
  factory _$$AgentTurnMessageImplCopyWith(
    _$AgentTurnMessageImpl value,
    $Res Function(_$AgentTurnMessageImpl) then,
  ) = __$$AgentTurnMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    AgentTurnRole role,
    String? content,
    List<AgentToolCall> toolCalls,
    String? toolCallId,
    bool toolError,
  });
}

/// @nodoc
class __$$AgentTurnMessageImplCopyWithImpl<$Res>
    extends _$AgentTurnMessageCopyWithImpl<$Res, _$AgentTurnMessageImpl>
    implements _$$AgentTurnMessageImplCopyWith<$Res> {
  __$$AgentTurnMessageImplCopyWithImpl(
    _$AgentTurnMessageImpl _value,
    $Res Function(_$AgentTurnMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgentTurnMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? role = null,
    Object? content = freezed,
    Object? toolCalls = null,
    Object? toolCallId = freezed,
    Object? toolError = null,
  }) {
    return _then(
      _$AgentTurnMessageImpl(
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as AgentTurnRole,
        content: freezed == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        toolCalls: null == toolCalls
            ? _value._toolCalls
            : toolCalls // ignore: cast_nullable_to_non_nullable
                  as List<AgentToolCall>,
        toolCallId: freezed == toolCallId
            ? _value.toolCallId
            : toolCallId // ignore: cast_nullable_to_non_nullable
                  as String?,
        toolError: null == toolError
            ? _value.toolError
            : toolError // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AgentTurnMessageImpl implements _AgentTurnMessage {
  const _$AgentTurnMessageImpl({
    required this.role,
    this.content,
    final List<AgentToolCall> toolCalls = const [],
    this.toolCallId,
    this.toolError = false,
  }) : _toolCalls = toolCalls;

  factory _$AgentTurnMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentTurnMessageImplFromJson(json);

  @override
  final AgentTurnRole role;
  @override
  final String? content;
  final List<AgentToolCall> _toolCalls;
  @override
  @JsonKey()
  List<AgentToolCall> get toolCalls {
    if (_toolCalls is EqualUnmodifiableListView) return _toolCalls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_toolCalls);
  }

  @override
  final String? toolCallId;
  @override
  @JsonKey()
  final bool toolError;

  @override
  String toString() {
    return 'AgentTurnMessage(role: $role, content: $content, toolCalls: $toolCalls, toolCallId: $toolCallId, toolError: $toolError)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentTurnMessageImpl &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.content, content) || other.content == content) &&
            const DeepCollectionEquality().equals(
              other._toolCalls,
              _toolCalls,
            ) &&
            (identical(other.toolCallId, toolCallId) ||
                other.toolCallId == toolCallId) &&
            (identical(other.toolError, toolError) ||
                other.toolError == toolError));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    role,
    content,
    const DeepCollectionEquality().hash(_toolCalls),
    toolCallId,
    toolError,
  );

  /// Create a copy of AgentTurnMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentTurnMessageImplCopyWith<_$AgentTurnMessageImpl> get copyWith =>
      __$$AgentTurnMessageImplCopyWithImpl<_$AgentTurnMessageImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentTurnMessageImplToJson(this);
  }
}

abstract class _AgentTurnMessage implements AgentTurnMessage {
  const factory _AgentTurnMessage({
    required final AgentTurnRole role,
    final String? content,
    final List<AgentToolCall> toolCalls,
    final String? toolCallId,
    final bool toolError,
  }) = _$AgentTurnMessageImpl;

  factory _AgentTurnMessage.fromJson(Map<String, dynamic> json) =
      _$AgentTurnMessageImpl.fromJson;

  @override
  AgentTurnRole get role;
  @override
  String? get content;
  @override
  List<AgentToolCall> get toolCalls;
  @override
  String? get toolCallId;
  @override
  bool get toolError;

  /// Create a copy of AgentTurnMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentTurnMessageImplCopyWith<_$AgentTurnMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AgentTurnRequest _$AgentTurnRequestFromJson(Map<String, dynamic> json) {
  return _AgentTurnRequest.fromJson(json);
}

/// @nodoc
mixin _$AgentTurnRequest {
  String get systemPrompt => throw _privateConstructorUsedError;
  String get userContent => throw _privateConstructorUsedError;
  List<ToolDefinition> get tools => throw _privateConstructorUsedError;
  List<AgentTurnMessage> get history => throw _privateConstructorUsedError;
  int get timeoutSeconds => throw _privateConstructorUsedError;
  double get temperature => throw _privateConstructorUsedError;

  /// Serializes this AgentTurnRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgentTurnRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgentTurnRequestCopyWith<AgentTurnRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentTurnRequestCopyWith<$Res> {
  factory $AgentTurnRequestCopyWith(
    AgentTurnRequest value,
    $Res Function(AgentTurnRequest) then,
  ) = _$AgentTurnRequestCopyWithImpl<$Res, AgentTurnRequest>;
  @useResult
  $Res call({
    String systemPrompt,
    String userContent,
    List<ToolDefinition> tools,
    List<AgentTurnMessage> history,
    int timeoutSeconds,
    double temperature,
  });
}

/// @nodoc
class _$AgentTurnRequestCopyWithImpl<$Res, $Val extends AgentTurnRequest>
    implements $AgentTurnRequestCopyWith<$Res> {
  _$AgentTurnRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentTurnRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? systemPrompt = null,
    Object? userContent = null,
    Object? tools = null,
    Object? history = null,
    Object? timeoutSeconds = null,
    Object? temperature = null,
  }) {
    return _then(
      _value.copyWith(
            systemPrompt: null == systemPrompt
                ? _value.systemPrompt
                : systemPrompt // ignore: cast_nullable_to_non_nullable
                      as String,
            userContent: null == userContent
                ? _value.userContent
                : userContent // ignore: cast_nullable_to_non_nullable
                      as String,
            tools: null == tools
                ? _value.tools
                : tools // ignore: cast_nullable_to_non_nullable
                      as List<ToolDefinition>,
            history: null == history
                ? _value.history
                : history // ignore: cast_nullable_to_non_nullable
                      as List<AgentTurnMessage>,
            timeoutSeconds: null == timeoutSeconds
                ? _value.timeoutSeconds
                : timeoutSeconds // ignore: cast_nullable_to_non_nullable
                      as int,
            temperature: null == temperature
                ? _value.temperature
                : temperature // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AgentTurnRequestImplCopyWith<$Res>
    implements $AgentTurnRequestCopyWith<$Res> {
  factory _$$AgentTurnRequestImplCopyWith(
    _$AgentTurnRequestImpl value,
    $Res Function(_$AgentTurnRequestImpl) then,
  ) = __$$AgentTurnRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String systemPrompt,
    String userContent,
    List<ToolDefinition> tools,
    List<AgentTurnMessage> history,
    int timeoutSeconds,
    double temperature,
  });
}

/// @nodoc
class __$$AgentTurnRequestImplCopyWithImpl<$Res>
    extends _$AgentTurnRequestCopyWithImpl<$Res, _$AgentTurnRequestImpl>
    implements _$$AgentTurnRequestImplCopyWith<$Res> {
  __$$AgentTurnRequestImplCopyWithImpl(
    _$AgentTurnRequestImpl _value,
    $Res Function(_$AgentTurnRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgentTurnRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? systemPrompt = null,
    Object? userContent = null,
    Object? tools = null,
    Object? history = null,
    Object? timeoutSeconds = null,
    Object? temperature = null,
  }) {
    return _then(
      _$AgentTurnRequestImpl(
        systemPrompt: null == systemPrompt
            ? _value.systemPrompt
            : systemPrompt // ignore: cast_nullable_to_non_nullable
                  as String,
        userContent: null == userContent
            ? _value.userContent
            : userContent // ignore: cast_nullable_to_non_nullable
                  as String,
        tools: null == tools
            ? _value._tools
            : tools // ignore: cast_nullable_to_non_nullable
                  as List<ToolDefinition>,
        history: null == history
            ? _value._history
            : history // ignore: cast_nullable_to_non_nullable
                  as List<AgentTurnMessage>,
        timeoutSeconds: null == timeoutSeconds
            ? _value.timeoutSeconds
            : timeoutSeconds // ignore: cast_nullable_to_non_nullable
                  as int,
        temperature: null == temperature
            ? _value.temperature
            : temperature // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AgentTurnRequestImpl implements _AgentTurnRequest {
  const _$AgentTurnRequestImpl({
    required this.systemPrompt,
    required this.userContent,
    final List<ToolDefinition> tools = const [],
    final List<AgentTurnMessage> history = const [],
    this.timeoutSeconds = 60,
    this.temperature = 0.1,
  }) : _tools = tools,
       _history = history;

  factory _$AgentTurnRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentTurnRequestImplFromJson(json);

  @override
  final String systemPrompt;
  @override
  final String userContent;
  final List<ToolDefinition> _tools;
  @override
  @JsonKey()
  List<ToolDefinition> get tools {
    if (_tools is EqualUnmodifiableListView) return _tools;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tools);
  }

  final List<AgentTurnMessage> _history;
  @override
  @JsonKey()
  List<AgentTurnMessage> get history {
    if (_history is EqualUnmodifiableListView) return _history;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_history);
  }

  @override
  @JsonKey()
  final int timeoutSeconds;
  @override
  @JsonKey()
  final double temperature;

  @override
  String toString() {
    return 'AgentTurnRequest(systemPrompt: $systemPrompt, userContent: $userContent, tools: $tools, history: $history, timeoutSeconds: $timeoutSeconds, temperature: $temperature)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentTurnRequestImpl &&
            (identical(other.systemPrompt, systemPrompt) ||
                other.systemPrompt == systemPrompt) &&
            (identical(other.userContent, userContent) ||
                other.userContent == userContent) &&
            const DeepCollectionEquality().equals(other._tools, _tools) &&
            const DeepCollectionEquality().equals(other._history, _history) &&
            (identical(other.timeoutSeconds, timeoutSeconds) ||
                other.timeoutSeconds == timeoutSeconds) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    systemPrompt,
    userContent,
    const DeepCollectionEquality().hash(_tools),
    const DeepCollectionEquality().hash(_history),
    timeoutSeconds,
    temperature,
  );

  /// Create a copy of AgentTurnRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentTurnRequestImplCopyWith<_$AgentTurnRequestImpl> get copyWith =>
      __$$AgentTurnRequestImplCopyWithImpl<_$AgentTurnRequestImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentTurnRequestImplToJson(this);
  }
}

abstract class _AgentTurnRequest implements AgentTurnRequest {
  const factory _AgentTurnRequest({
    required final String systemPrompt,
    required final String userContent,
    final List<ToolDefinition> tools,
    final List<AgentTurnMessage> history,
    final int timeoutSeconds,
    final double temperature,
  }) = _$AgentTurnRequestImpl;

  factory _AgentTurnRequest.fromJson(Map<String, dynamic> json) =
      _$AgentTurnRequestImpl.fromJson;

  @override
  String get systemPrompt;
  @override
  String get userContent;
  @override
  List<ToolDefinition> get tools;
  @override
  List<AgentTurnMessage> get history;
  @override
  int get timeoutSeconds;
  @override
  double get temperature;

  /// Create a copy of AgentTurnRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentTurnRequestImplCopyWith<_$AgentTurnRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AgentToolCallRecord _$AgentToolCallRecordFromJson(Map<String, dynamic> json) {
  return _AgentToolCallRecord.fromJson(json);
}

/// @nodoc
mixin _$AgentToolCallRecord {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  Map<String, dynamic> get args => throw _privateConstructorUsedError;
  bool get success => throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  int get durationMs => throw _privateConstructorUsedError;

  /// Serializes this AgentToolCallRecord to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgentToolCallRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgentToolCallRecordCopyWith<AgentToolCallRecord> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentToolCallRecordCopyWith<$Res> {
  factory $AgentToolCallRecordCopyWith(
    AgentToolCallRecord value,
    $Res Function(AgentToolCallRecord) then,
  ) = _$AgentToolCallRecordCopyWithImpl<$Res, AgentToolCallRecord>;
  @useResult
  $Res call({
    String id,
    String name,
    Map<String, dynamic> args,
    bool success,
    String summary,
    int durationMs,
  });
}

/// @nodoc
class _$AgentToolCallRecordCopyWithImpl<$Res, $Val extends AgentToolCallRecord>
    implements $AgentToolCallRecordCopyWith<$Res> {
  _$AgentToolCallRecordCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentToolCallRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? args = null,
    Object? success = null,
    Object? summary = null,
    Object? durationMs = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            args: null == args
                ? _value.args
                : args // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            success: null == success
                ? _value.success
                : success // ignore: cast_nullable_to_non_nullable
                      as bool,
            summary: null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String,
            durationMs: null == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AgentToolCallRecordImplCopyWith<$Res>
    implements $AgentToolCallRecordCopyWith<$Res> {
  factory _$$AgentToolCallRecordImplCopyWith(
    _$AgentToolCallRecordImpl value,
    $Res Function(_$AgentToolCallRecordImpl) then,
  ) = __$$AgentToolCallRecordImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    Map<String, dynamic> args,
    bool success,
    String summary,
    int durationMs,
  });
}

/// @nodoc
class __$$AgentToolCallRecordImplCopyWithImpl<$Res>
    extends _$AgentToolCallRecordCopyWithImpl<$Res, _$AgentToolCallRecordImpl>
    implements _$$AgentToolCallRecordImplCopyWith<$Res> {
  __$$AgentToolCallRecordImplCopyWithImpl(
    _$AgentToolCallRecordImpl _value,
    $Res Function(_$AgentToolCallRecordImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgentToolCallRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? args = null,
    Object? success = null,
    Object? summary = null,
    Object? durationMs = null,
  }) {
    return _then(
      _$AgentToolCallRecordImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        args: null == args
            ? _value._args
            : args // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        success: null == success
            ? _value.success
            : success // ignore: cast_nullable_to_non_nullable
                  as bool,
        summary: null == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String,
        durationMs: null == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AgentToolCallRecordImpl implements _AgentToolCallRecord {
  const _$AgentToolCallRecordImpl({
    required this.id,
    required this.name,
    final Map<String, dynamic> args = const {},
    required this.success,
    this.summary = '',
    this.durationMs = 0,
  }) : _args = args;

  factory _$AgentToolCallRecordImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentToolCallRecordImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final Map<String, dynamic> _args;
  @override
  @JsonKey()
  Map<String, dynamic> get args {
    if (_args is EqualUnmodifiableMapView) return _args;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_args);
  }

  @override
  final bool success;
  @override
  @JsonKey()
  final String summary;
  @override
  @JsonKey()
  final int durationMs;

  @override
  String toString() {
    return 'AgentToolCallRecord(id: $id, name: $name, args: $args, success: $success, summary: $summary, durationMs: $durationMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentToolCallRecordImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._args, _args) &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    const DeepCollectionEquality().hash(_args),
    success,
    summary,
    durationMs,
  );

  /// Create a copy of AgentToolCallRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentToolCallRecordImplCopyWith<_$AgentToolCallRecordImpl> get copyWith =>
      __$$AgentToolCallRecordImplCopyWithImpl<_$AgentToolCallRecordImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentToolCallRecordImplToJson(this);
  }
}

abstract class _AgentToolCallRecord implements AgentToolCallRecord {
  const factory _AgentToolCallRecord({
    required final String id,
    required final String name,
    final Map<String, dynamic> args,
    required final bool success,
    final String summary,
    final int durationMs,
  }) = _$AgentToolCallRecordImpl;

  factory _AgentToolCallRecord.fromJson(Map<String, dynamic> json) =
      _$AgentToolCallRecordImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  Map<String, dynamic> get args;
  @override
  bool get success;
  @override
  String get summary;
  @override
  int get durationMs;

  /// Create a copy of AgentToolCallRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentToolCallRecordImplCopyWith<_$AgentToolCallRecordImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AgentTurnResult _$AgentTurnResultFromJson(Map<String, dynamic> json) {
  return _AgentTurnResult.fromJson(json);
}

/// @nodoc
mixin _$AgentTurnResult {
  String get text => throw _privateConstructorUsedError;
  List<AgentToolCall> get toolCalls => throw _privateConstructorUsedError;
  List<AgentToolCallRecord> get records => throw _privateConstructorUsedError;
  AgentTurnStopReason get stopReason => throw _privateConstructorUsedError;

  /// Serializes this AgentTurnResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AgentTurnResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgentTurnResultCopyWith<AgentTurnResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentTurnResultCopyWith<$Res> {
  factory $AgentTurnResultCopyWith(
    AgentTurnResult value,
    $Res Function(AgentTurnResult) then,
  ) = _$AgentTurnResultCopyWithImpl<$Res, AgentTurnResult>;
  @useResult
  $Res call({
    String text,
    List<AgentToolCall> toolCalls,
    List<AgentToolCallRecord> records,
    AgentTurnStopReason stopReason,
  });
}

/// @nodoc
class _$AgentTurnResultCopyWithImpl<$Res, $Val extends AgentTurnResult>
    implements $AgentTurnResultCopyWith<$Res> {
  _$AgentTurnResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentTurnResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? toolCalls = null,
    Object? records = null,
    Object? stopReason = null,
  }) {
    return _then(
      _value.copyWith(
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            toolCalls: null == toolCalls
                ? _value.toolCalls
                : toolCalls // ignore: cast_nullable_to_non_nullable
                      as List<AgentToolCall>,
            records: null == records
                ? _value.records
                : records // ignore: cast_nullable_to_non_nullable
                      as List<AgentToolCallRecord>,
            stopReason: null == stopReason
                ? _value.stopReason
                : stopReason // ignore: cast_nullable_to_non_nullable
                      as AgentTurnStopReason,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AgentTurnResultImplCopyWith<$Res>
    implements $AgentTurnResultCopyWith<$Res> {
  factory _$$AgentTurnResultImplCopyWith(
    _$AgentTurnResultImpl value,
    $Res Function(_$AgentTurnResultImpl) then,
  ) = __$$AgentTurnResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String text,
    List<AgentToolCall> toolCalls,
    List<AgentToolCallRecord> records,
    AgentTurnStopReason stopReason,
  });
}

/// @nodoc
class __$$AgentTurnResultImplCopyWithImpl<$Res>
    extends _$AgentTurnResultCopyWithImpl<$Res, _$AgentTurnResultImpl>
    implements _$$AgentTurnResultImplCopyWith<$Res> {
  __$$AgentTurnResultImplCopyWithImpl(
    _$AgentTurnResultImpl _value,
    $Res Function(_$AgentTurnResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgentTurnResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? toolCalls = null,
    Object? records = null,
    Object? stopReason = null,
  }) {
    return _then(
      _$AgentTurnResultImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        toolCalls: null == toolCalls
            ? _value._toolCalls
            : toolCalls // ignore: cast_nullable_to_non_nullable
                  as List<AgentToolCall>,
        records: null == records
            ? _value._records
            : records // ignore: cast_nullable_to_non_nullable
                  as List<AgentToolCallRecord>,
        stopReason: null == stopReason
            ? _value.stopReason
            : stopReason // ignore: cast_nullable_to_non_nullable
                  as AgentTurnStopReason,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AgentTurnResultImpl implements _AgentTurnResult {
  const _$AgentTurnResultImpl({
    this.text = '',
    final List<AgentToolCall> toolCalls = const [],
    final List<AgentToolCallRecord> records = const [],
    this.stopReason = AgentTurnStopReason.stop,
  }) : _toolCalls = toolCalls,
       _records = records;

  factory _$AgentTurnResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$AgentTurnResultImplFromJson(json);

  @override
  @JsonKey()
  final String text;
  final List<AgentToolCall> _toolCalls;
  @override
  @JsonKey()
  List<AgentToolCall> get toolCalls {
    if (_toolCalls is EqualUnmodifiableListView) return _toolCalls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_toolCalls);
  }

  final List<AgentToolCallRecord> _records;
  @override
  @JsonKey()
  List<AgentToolCallRecord> get records {
    if (_records is EqualUnmodifiableListView) return _records;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_records);
  }

  @override
  @JsonKey()
  final AgentTurnStopReason stopReason;

  @override
  String toString() {
    return 'AgentTurnResult(text: $text, toolCalls: $toolCalls, records: $records, stopReason: $stopReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentTurnResultImpl &&
            (identical(other.text, text) || other.text == text) &&
            const DeepCollectionEquality().equals(
              other._toolCalls,
              _toolCalls,
            ) &&
            const DeepCollectionEquality().equals(other._records, _records) &&
            (identical(other.stopReason, stopReason) ||
                other.stopReason == stopReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    text,
    const DeepCollectionEquality().hash(_toolCalls),
    const DeepCollectionEquality().hash(_records),
    stopReason,
  );

  /// Create a copy of AgentTurnResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentTurnResultImplCopyWith<_$AgentTurnResultImpl> get copyWith =>
      __$$AgentTurnResultImplCopyWithImpl<_$AgentTurnResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AgentTurnResultImplToJson(this);
  }
}

abstract class _AgentTurnResult implements AgentTurnResult {
  const factory _AgentTurnResult({
    final String text,
    final List<AgentToolCall> toolCalls,
    final List<AgentToolCallRecord> records,
    final AgentTurnStopReason stopReason,
  }) = _$AgentTurnResultImpl;

  factory _AgentTurnResult.fromJson(Map<String, dynamic> json) =
      _$AgentTurnResultImpl.fromJson;

  @override
  String get text;
  @override
  List<AgentToolCall> get toolCalls;
  @override
  List<AgentToolCallRecord> get records;
  @override
  AgentTurnStopReason get stopReason;

  /// Create a copy of AgentTurnResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentTurnResultImplCopyWith<_$AgentTurnResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
