// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_step.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ChatStep _$ChatStepFromJson(Map<String, dynamic> json) {
  return _ChatStep.fromJson(json);
}

/// @nodoc
mixin _$ChatStep {
  String get toolCallId => throw _privateConstructorUsedError;
  String get toolName => throw _privateConstructorUsedError;
  Map<String, dynamic> get args => throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  bool get success => throw _privateConstructorUsedError;
  int get durationMs => throw _privateConstructorUsedError;
  int get round => throw _privateConstructorUsedError;
  ChatStepKind get kind => throw _privateConstructorUsedError;

  /// Serializes this ChatStep to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChatStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChatStepCopyWith<ChatStep> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatStepCopyWith<$Res> {
  factory $ChatStepCopyWith(ChatStep value, $Res Function(ChatStep) then) =
      _$ChatStepCopyWithImpl<$Res, ChatStep>;
  @useResult
  $Res call({
    String toolCallId,
    String toolName,
    Map<String, dynamic> args,
    String summary,
    bool success,
    int durationMs,
    int round,
    ChatStepKind kind,
  });
}

/// @nodoc
class _$ChatStepCopyWithImpl<$Res, $Val extends ChatStep>
    implements $ChatStepCopyWith<$Res> {
  _$ChatStepCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChatStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toolCallId = null,
    Object? toolName = null,
    Object? args = null,
    Object? summary = null,
    Object? success = null,
    Object? durationMs = null,
    Object? round = null,
    Object? kind = null,
  }) {
    return _then(
      _value.copyWith(
            toolCallId: null == toolCallId
                ? _value.toolCallId
                : toolCallId // ignore: cast_nullable_to_non_nullable
                      as String,
            toolName: null == toolName
                ? _value.toolName
                : toolName // ignore: cast_nullable_to_non_nullable
                      as String,
            args: null == args
                ? _value.args
                : args // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            summary: null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String,
            success: null == success
                ? _value.success
                : success // ignore: cast_nullable_to_non_nullable
                      as bool,
            durationMs: null == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int,
            round: null == round
                ? _value.round
                : round // ignore: cast_nullable_to_non_nullable
                      as int,
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as ChatStepKind,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChatStepImplCopyWith<$Res>
    implements $ChatStepCopyWith<$Res> {
  factory _$$ChatStepImplCopyWith(
    _$ChatStepImpl value,
    $Res Function(_$ChatStepImpl) then,
  ) = __$$ChatStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String toolCallId,
    String toolName,
    Map<String, dynamic> args,
    String summary,
    bool success,
    int durationMs,
    int round,
    ChatStepKind kind,
  });
}

/// @nodoc
class __$$ChatStepImplCopyWithImpl<$Res>
    extends _$ChatStepCopyWithImpl<$Res, _$ChatStepImpl>
    implements _$$ChatStepImplCopyWith<$Res> {
  __$$ChatStepImplCopyWithImpl(
    _$ChatStepImpl _value,
    $Res Function(_$ChatStepImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChatStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? toolCallId = null,
    Object? toolName = null,
    Object? args = null,
    Object? summary = null,
    Object? success = null,
    Object? durationMs = null,
    Object? round = null,
    Object? kind = null,
  }) {
    return _then(
      _$ChatStepImpl(
        toolCallId: null == toolCallId
            ? _value.toolCallId
            : toolCallId // ignore: cast_nullable_to_non_nullable
                  as String,
        toolName: null == toolName
            ? _value.toolName
            : toolName // ignore: cast_nullable_to_non_nullable
                  as String,
        args: null == args
            ? _value._args
            : args // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        summary: null == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String,
        success: null == success
            ? _value.success
            : success // ignore: cast_nullable_to_non_nullable
                  as bool,
        durationMs: null == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int,
        round: null == round
            ? _value.round
            : round // ignore: cast_nullable_to_non_nullable
                  as int,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as ChatStepKind,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChatStepImpl implements _ChatStep {
  const _$ChatStepImpl({
    required this.toolCallId,
    required this.toolName,
    final Map<String, dynamic> args = const {},
    this.summary = '',
    this.success = false,
    this.durationMs = 0,
    this.round = 0,
    this.kind = ChatStepKind.read,
  }) : _args = args;

  factory _$ChatStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChatStepImplFromJson(json);

  @override
  final String toolCallId;
  @override
  final String toolName;
  final Map<String, dynamic> _args;
  @override
  @JsonKey()
  Map<String, dynamic> get args {
    if (_args is EqualUnmodifiableMapView) return _args;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_args);
  }

  @override
  @JsonKey()
  final String summary;
  @override
  @JsonKey()
  final bool success;
  @override
  @JsonKey()
  final int durationMs;
  @override
  @JsonKey()
  final int round;
  @override
  @JsonKey()
  final ChatStepKind kind;

  @override
  String toString() {
    return 'ChatStep(toolCallId: $toolCallId, toolName: $toolName, args: $args, summary: $summary, success: $success, durationMs: $durationMs, round: $round, kind: $kind)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatStepImpl &&
            (identical(other.toolCallId, toolCallId) ||
                other.toolCallId == toolCallId) &&
            (identical(other.toolName, toolName) ||
                other.toolName == toolName) &&
            const DeepCollectionEquality().equals(other._args, _args) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.round, round) || other.round == round) &&
            (identical(other.kind, kind) || other.kind == kind));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    toolCallId,
    toolName,
    const DeepCollectionEquality().hash(_args),
    summary,
    success,
    durationMs,
    round,
    kind,
  );

  /// Create a copy of ChatStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatStepImplCopyWith<_$ChatStepImpl> get copyWith =>
      __$$ChatStepImplCopyWithImpl<_$ChatStepImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChatStepImplToJson(this);
  }
}

abstract class _ChatStep implements ChatStep {
  const factory _ChatStep({
    required final String toolCallId,
    required final String toolName,
    final Map<String, dynamic> args,
    final String summary,
    final bool success,
    final int durationMs,
    final int round,
    final ChatStepKind kind,
  }) = _$ChatStepImpl;

  factory _ChatStep.fromJson(Map<String, dynamic> json) =
      _$ChatStepImpl.fromJson;

  @override
  String get toolCallId;
  @override
  String get toolName;
  @override
  Map<String, dynamic> get args;
  @override
  String get summary;
  @override
  bool get success;
  @override
  int get durationMs;
  @override
  int get round;
  @override
  ChatStepKind get kind;

  /// Create a copy of ChatStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChatStepImplCopyWith<_$ChatStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
