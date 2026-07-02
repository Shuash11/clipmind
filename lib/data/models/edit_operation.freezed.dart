// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'edit_operation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EditOperation _$EditOperationFromJson(Map<String, dynamic> json) {
  return _EditOperation.fromJson(json);
}

/// @nodoc
mixin _$EditOperation {
  String get id => throw _privateConstructorUsedError;
  EditOperationType get type => throw _privateConstructorUsedError;
  List<String> get targetClipIds => throw _privateConstructorUsedError;
  Map<String, dynamic> get params => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get sourceChatMessageId => throw _privateConstructorUsedError;
  OperationStatus get status => throw _privateConstructorUsedError;
  String? get ffmpegCommand => throw _privateConstructorUsedError;

  /// Serializes this EditOperation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EditOperation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EditOperationCopyWith<EditOperation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EditOperationCopyWith<$Res> {
  factory $EditOperationCopyWith(
    EditOperation value,
    $Res Function(EditOperation) then,
  ) = _$EditOperationCopyWithImpl<$Res, EditOperation>;
  @useResult
  $Res call({
    String id,
    EditOperationType type,
    List<String> targetClipIds,
    Map<String, dynamic> params,
    DateTime createdAt,
    String sourceChatMessageId,
    OperationStatus status,
    String? ffmpegCommand,
  });
}

/// @nodoc
class _$EditOperationCopyWithImpl<$Res, $Val extends EditOperation>
    implements $EditOperationCopyWith<$Res> {
  _$EditOperationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EditOperation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? targetClipIds = null,
    Object? params = null,
    Object? createdAt = null,
    Object? sourceChatMessageId = null,
    Object? status = null,
    Object? ffmpegCommand = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as EditOperationType,
            targetClipIds: null == targetClipIds
                ? _value.targetClipIds
                : targetClipIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            params: null == params
                ? _value.params
                : params // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            sourceChatMessageId: null == sourceChatMessageId
                ? _value.sourceChatMessageId
                : sourceChatMessageId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as OperationStatus,
            ffmpegCommand: freezed == ffmpegCommand
                ? _value.ffmpegCommand
                : ffmpegCommand // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EditOperationImplCopyWith<$Res>
    implements $EditOperationCopyWith<$Res> {
  factory _$$EditOperationImplCopyWith(
    _$EditOperationImpl value,
    $Res Function(_$EditOperationImpl) then,
  ) = __$$EditOperationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    EditOperationType type,
    List<String> targetClipIds,
    Map<String, dynamic> params,
    DateTime createdAt,
    String sourceChatMessageId,
    OperationStatus status,
    String? ffmpegCommand,
  });
}

/// @nodoc
class __$$EditOperationImplCopyWithImpl<$Res>
    extends _$EditOperationCopyWithImpl<$Res, _$EditOperationImpl>
    implements _$$EditOperationImplCopyWith<$Res> {
  __$$EditOperationImplCopyWithImpl(
    _$EditOperationImpl _value,
    $Res Function(_$EditOperationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EditOperation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? targetClipIds = null,
    Object? params = null,
    Object? createdAt = null,
    Object? sourceChatMessageId = null,
    Object? status = null,
    Object? ffmpegCommand = freezed,
  }) {
    return _then(
      _$EditOperationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as EditOperationType,
        targetClipIds: null == targetClipIds
            ? _value._targetClipIds
            : targetClipIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        params: null == params
            ? _value._params
            : params // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        sourceChatMessageId: null == sourceChatMessageId
            ? _value.sourceChatMessageId
            : sourceChatMessageId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as OperationStatus,
        ffmpegCommand: freezed == ffmpegCommand
            ? _value.ffmpegCommand
            : ffmpegCommand // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EditOperationImpl implements _EditOperation {
  const _$EditOperationImpl({
    required this.id,
    required this.type,
    final List<String> targetClipIds = const [],
    final Map<String, dynamic> params = const {},
    required this.createdAt,
    this.sourceChatMessageId = '',
    this.status = OperationStatus.applied,
    this.ffmpegCommand,
  }) : _targetClipIds = targetClipIds,
       _params = params;

  factory _$EditOperationImpl.fromJson(Map<String, dynamic> json) =>
      _$$EditOperationImplFromJson(json);

  @override
  final String id;
  @override
  final EditOperationType type;
  final List<String> _targetClipIds;
  @override
  @JsonKey()
  List<String> get targetClipIds {
    if (_targetClipIds is EqualUnmodifiableListView) return _targetClipIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targetClipIds);
  }

  final Map<String, dynamic> _params;
  @override
  @JsonKey()
  Map<String, dynamic> get params {
    if (_params is EqualUnmodifiableMapView) return _params;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_params);
  }

  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final String sourceChatMessageId;
  @override
  @JsonKey()
  final OperationStatus status;
  @override
  final String? ffmpegCommand;

  @override
  String toString() {
    return 'EditOperation(id: $id, type: $type, targetClipIds: $targetClipIds, params: $params, createdAt: $createdAt, sourceChatMessageId: $sourceChatMessageId, status: $status, ffmpegCommand: $ffmpegCommand)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EditOperationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(
              other._targetClipIds,
              _targetClipIds,
            ) &&
            const DeepCollectionEquality().equals(other._params, _params) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.sourceChatMessageId, sourceChatMessageId) ||
                other.sourceChatMessageId == sourceChatMessageId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.ffmpegCommand, ffmpegCommand) ||
                other.ffmpegCommand == ffmpegCommand));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    const DeepCollectionEquality().hash(_targetClipIds),
    const DeepCollectionEquality().hash(_params),
    createdAt,
    sourceChatMessageId,
    status,
    ffmpegCommand,
  );

  /// Create a copy of EditOperation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EditOperationImplCopyWith<_$EditOperationImpl> get copyWith =>
      __$$EditOperationImplCopyWithImpl<_$EditOperationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EditOperationImplToJson(this);
  }
}

abstract class _EditOperation implements EditOperation {
  const factory _EditOperation({
    required final String id,
    required final EditOperationType type,
    final List<String> targetClipIds,
    final Map<String, dynamic> params,
    required final DateTime createdAt,
    final String sourceChatMessageId,
    final OperationStatus status,
    final String? ffmpegCommand,
  }) = _$EditOperationImpl;

  factory _EditOperation.fromJson(Map<String, dynamic> json) =
      _$EditOperationImpl.fromJson;

  @override
  String get id;
  @override
  EditOperationType get type;
  @override
  List<String> get targetClipIds;
  @override
  Map<String, dynamic> get params;
  @override
  DateTime get createdAt;
  @override
  String get sourceChatMessageId;
  @override
  OperationStatus get status;
  @override
  String? get ffmpegCommand;

  /// Create a copy of EditOperation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EditOperationImplCopyWith<_$EditOperationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
