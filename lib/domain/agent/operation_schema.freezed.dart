// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'operation_schema.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

EditOperationSet _$EditOperationSetFromJson(Map<String, dynamic> json) {
  return _EditOperationSet.fromJson(json);
}

/// @nodoc
mixin _$EditOperationSet {
  List<EditOperationRequest> get operations =>
      throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  String? get clarificationNeeded => throw _privateConstructorUsedError;

  /// Serializes this EditOperationSet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EditOperationSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EditOperationSetCopyWith<EditOperationSet> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EditOperationSetCopyWith<$Res> {
  factory $EditOperationSetCopyWith(
    EditOperationSet value,
    $Res Function(EditOperationSet) then,
  ) = _$EditOperationSetCopyWithImpl<$Res, EditOperationSet>;
  @useResult
  $Res call({
    List<EditOperationRequest> operations,
    String summary,
    String? clarificationNeeded,
  });
}

/// @nodoc
class _$EditOperationSetCopyWithImpl<$Res, $Val extends EditOperationSet>
    implements $EditOperationSetCopyWith<$Res> {
  _$EditOperationSetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EditOperationSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? operations = null,
    Object? summary = null,
    Object? clarificationNeeded = freezed,
  }) {
    return _then(
      _value.copyWith(
            operations: null == operations
                ? _value.operations
                : operations // ignore: cast_nullable_to_non_nullable
                      as List<EditOperationRequest>,
            summary: null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String,
            clarificationNeeded: freezed == clarificationNeeded
                ? _value.clarificationNeeded
                : clarificationNeeded // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EditOperationSetImplCopyWith<$Res>
    implements $EditOperationSetCopyWith<$Res> {
  factory _$$EditOperationSetImplCopyWith(
    _$EditOperationSetImpl value,
    $Res Function(_$EditOperationSetImpl) then,
  ) = __$$EditOperationSetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<EditOperationRequest> operations,
    String summary,
    String? clarificationNeeded,
  });
}

/// @nodoc
class __$$EditOperationSetImplCopyWithImpl<$Res>
    extends _$EditOperationSetCopyWithImpl<$Res, _$EditOperationSetImpl>
    implements _$$EditOperationSetImplCopyWith<$Res> {
  __$$EditOperationSetImplCopyWithImpl(
    _$EditOperationSetImpl _value,
    $Res Function(_$EditOperationSetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EditOperationSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? operations = null,
    Object? summary = null,
    Object? clarificationNeeded = freezed,
  }) {
    return _then(
      _$EditOperationSetImpl(
        operations: null == operations
            ? _value._operations
            : operations // ignore: cast_nullable_to_non_nullable
                  as List<EditOperationRequest>,
        summary: null == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String,
        clarificationNeeded: freezed == clarificationNeeded
            ? _value.clarificationNeeded
            : clarificationNeeded // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EditOperationSetImpl implements _EditOperationSet {
  const _$EditOperationSetImpl({
    required final List<EditOperationRequest> operations,
    required this.summary,
    this.clarificationNeeded,
  }) : _operations = operations;

  factory _$EditOperationSetImpl.fromJson(Map<String, dynamic> json) =>
      _$$EditOperationSetImplFromJson(json);

  final List<EditOperationRequest> _operations;
  @override
  List<EditOperationRequest> get operations {
    if (_operations is EqualUnmodifiableListView) return _operations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_operations);
  }

  @override
  final String summary;
  @override
  final String? clarificationNeeded;

  @override
  String toString() {
    return 'EditOperationSet(operations: $operations, summary: $summary, clarificationNeeded: $clarificationNeeded)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EditOperationSetImpl &&
            const DeepCollectionEquality().equals(
              other._operations,
              _operations,
            ) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.clarificationNeeded, clarificationNeeded) ||
                other.clarificationNeeded == clarificationNeeded));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_operations),
    summary,
    clarificationNeeded,
  );

  /// Create a copy of EditOperationSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EditOperationSetImplCopyWith<_$EditOperationSetImpl> get copyWith =>
      __$$EditOperationSetImplCopyWithImpl<_$EditOperationSetImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EditOperationSetImplToJson(this);
  }
}

abstract class _EditOperationSet implements EditOperationSet {
  const factory _EditOperationSet({
    required final List<EditOperationRequest> operations,
    required final String summary,
    final String? clarificationNeeded,
  }) = _$EditOperationSetImpl;

  factory _EditOperationSet.fromJson(Map<String, dynamic> json) =
      _$EditOperationSetImpl.fromJson;

  @override
  List<EditOperationRequest> get operations;
  @override
  String get summary;
  @override
  String? get clarificationNeeded;

  /// Create a copy of EditOperationSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EditOperationSetImplCopyWith<_$EditOperationSetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EditOperationRequest _$EditOperationRequestFromJson(Map<String, dynamic> json) {
  return _EditOperationRequest.fromJson(json);
}

/// @nodoc
mixin _$EditOperationRequest {
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  dynamic get targetClipId => throw _privateConstructorUsedError;
  Map<String, dynamic> get params => throw _privateConstructorUsedError;

  /// Serializes this EditOperationRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EditOperationRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EditOperationRequestCopyWith<EditOperationRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EditOperationRequestCopyWith<$Res> {
  factory $EditOperationRequestCopyWith(
    EditOperationRequest value,
    $Res Function(EditOperationRequest) then,
  ) = _$EditOperationRequestCopyWithImpl<$Res, EditOperationRequest>;
  @useResult
  $Res call({
    String id,
    String type,
    dynamic targetClipId,
    Map<String, dynamic> params,
  });
}

/// @nodoc
class _$EditOperationRequestCopyWithImpl<
  $Res,
  $Val extends EditOperationRequest
>
    implements $EditOperationRequestCopyWith<$Res> {
  _$EditOperationRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EditOperationRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? targetClipId = freezed,
    Object? params = null,
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
                      as String,
            targetClipId: freezed == targetClipId
                ? _value.targetClipId
                : targetClipId // ignore: cast_nullable_to_non_nullable
                      as dynamic,
            params: null == params
                ? _value.params
                : params // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EditOperationRequestImplCopyWith<$Res>
    implements $EditOperationRequestCopyWith<$Res> {
  factory _$$EditOperationRequestImplCopyWith(
    _$EditOperationRequestImpl value,
    $Res Function(_$EditOperationRequestImpl) then,
  ) = __$$EditOperationRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String type,
    dynamic targetClipId,
    Map<String, dynamic> params,
  });
}

/// @nodoc
class __$$EditOperationRequestImplCopyWithImpl<$Res>
    extends _$EditOperationRequestCopyWithImpl<$Res, _$EditOperationRequestImpl>
    implements _$$EditOperationRequestImplCopyWith<$Res> {
  __$$EditOperationRequestImplCopyWithImpl(
    _$EditOperationRequestImpl _value,
    $Res Function(_$EditOperationRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EditOperationRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? targetClipId = freezed,
    Object? params = null,
  }) {
    return _then(
      _$EditOperationRequestImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        targetClipId: freezed == targetClipId
            ? _value.targetClipId
            : targetClipId // ignore: cast_nullable_to_non_nullable
                  as dynamic,
        params: null == params
            ? _value._params
            : params // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EditOperationRequestImpl implements _EditOperationRequest {
  const _$EditOperationRequestImpl({
    required this.id,
    required this.type,
    required this.targetClipId,
    required final Map<String, dynamic> params,
  }) : _params = params;

  factory _$EditOperationRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$EditOperationRequestImplFromJson(json);

  @override
  final String id;
  @override
  final String type;
  @override
  final dynamic targetClipId;
  final Map<String, dynamic> _params;
  @override
  Map<String, dynamic> get params {
    if (_params is EqualUnmodifiableMapView) return _params;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_params);
  }

  @override
  String toString() {
    return 'EditOperationRequest(id: $id, type: $type, targetClipId: $targetClipId, params: $params)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EditOperationRequestImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(
              other.targetClipId,
              targetClipId,
            ) &&
            const DeepCollectionEquality().equals(other._params, _params));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    const DeepCollectionEquality().hash(targetClipId),
    const DeepCollectionEquality().hash(_params),
  );

  /// Create a copy of EditOperationRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EditOperationRequestImplCopyWith<_$EditOperationRequestImpl>
  get copyWith =>
      __$$EditOperationRequestImplCopyWithImpl<_$EditOperationRequestImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EditOperationRequestImplToJson(this);
  }
}

abstract class _EditOperationRequest implements EditOperationRequest {
  const factory _EditOperationRequest({
    required final String id,
    required final String type,
    required final dynamic targetClipId,
    required final Map<String, dynamic> params,
  }) = _$EditOperationRequestImpl;

  factory _EditOperationRequest.fromJson(Map<String, dynamic> json) =
      _$EditOperationRequestImpl.fromJson;

  @override
  String get id;
  @override
  String get type;
  @override
  dynamic get targetClipId;
  @override
  Map<String, dynamic> get params;

  /// Create a copy of EditOperationRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EditOperationRequestImplCopyWith<_$EditOperationRequestImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ValidatedCommand {
  String get text => throw _privateConstructorUsedError;
  Map<String, int> get normalizedTimecodes =>
      throw _privateConstructorUsedError;
  ProjectSnapshot get projectSnapshot => throw _privateConstructorUsedError;

  /// Create a copy of ValidatedCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ValidatedCommandCopyWith<ValidatedCommand> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ValidatedCommandCopyWith<$Res> {
  factory $ValidatedCommandCopyWith(
    ValidatedCommand value,
    $Res Function(ValidatedCommand) then,
  ) = _$ValidatedCommandCopyWithImpl<$Res, ValidatedCommand>;
  @useResult
  $Res call({
    String text,
    Map<String, int> normalizedTimecodes,
    ProjectSnapshot projectSnapshot,
  });

  $ProjectSnapshotCopyWith<$Res> get projectSnapshot;
}

/// @nodoc
class _$ValidatedCommandCopyWithImpl<$Res, $Val extends ValidatedCommand>
    implements $ValidatedCommandCopyWith<$Res> {
  _$ValidatedCommandCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ValidatedCommand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? normalizedTimecodes = null,
    Object? projectSnapshot = null,
  }) {
    return _then(
      _value.copyWith(
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            normalizedTimecodes: null == normalizedTimecodes
                ? _value.normalizedTimecodes
                : normalizedTimecodes // ignore: cast_nullable_to_non_nullable
                      as Map<String, int>,
            projectSnapshot: null == projectSnapshot
                ? _value.projectSnapshot
                : projectSnapshot // ignore: cast_nullable_to_non_nullable
                      as ProjectSnapshot,
          )
          as $Val,
    );
  }

  /// Create a copy of ValidatedCommand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProjectSnapshotCopyWith<$Res> get projectSnapshot {
    return $ProjectSnapshotCopyWith<$Res>(_value.projectSnapshot, (value) {
      return _then(_value.copyWith(projectSnapshot: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ValidatedCommandImplCopyWith<$Res>
    implements $ValidatedCommandCopyWith<$Res> {
  factory _$$ValidatedCommandImplCopyWith(
    _$ValidatedCommandImpl value,
    $Res Function(_$ValidatedCommandImpl) then,
  ) = __$$ValidatedCommandImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String text,
    Map<String, int> normalizedTimecodes,
    ProjectSnapshot projectSnapshot,
  });

  @override
  $ProjectSnapshotCopyWith<$Res> get projectSnapshot;
}

/// @nodoc
class __$$ValidatedCommandImplCopyWithImpl<$Res>
    extends _$ValidatedCommandCopyWithImpl<$Res, _$ValidatedCommandImpl>
    implements _$$ValidatedCommandImplCopyWith<$Res> {
  __$$ValidatedCommandImplCopyWithImpl(
    _$ValidatedCommandImpl _value,
    $Res Function(_$ValidatedCommandImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ValidatedCommand
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? normalizedTimecodes = null,
    Object? projectSnapshot = null,
  }) {
    return _then(
      _$ValidatedCommandImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        normalizedTimecodes: null == normalizedTimecodes
            ? _value._normalizedTimecodes
            : normalizedTimecodes // ignore: cast_nullable_to_non_nullable
                  as Map<String, int>,
        projectSnapshot: null == projectSnapshot
            ? _value.projectSnapshot
            : projectSnapshot // ignore: cast_nullable_to_non_nullable
                  as ProjectSnapshot,
      ),
    );
  }
}

/// @nodoc

class _$ValidatedCommandImpl implements _ValidatedCommand {
  const _$ValidatedCommandImpl({
    required this.text,
    required final Map<String, int> normalizedTimecodes,
    required this.projectSnapshot,
  }) : _normalizedTimecodes = normalizedTimecodes;

  @override
  final String text;
  final Map<String, int> _normalizedTimecodes;
  @override
  Map<String, int> get normalizedTimecodes {
    if (_normalizedTimecodes is EqualUnmodifiableMapView)
      return _normalizedTimecodes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_normalizedTimecodes);
  }

  @override
  final ProjectSnapshot projectSnapshot;

  @override
  String toString() {
    return 'ValidatedCommand(text: $text, normalizedTimecodes: $normalizedTimecodes, projectSnapshot: $projectSnapshot)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ValidatedCommandImpl &&
            (identical(other.text, text) || other.text == text) &&
            const DeepCollectionEquality().equals(
              other._normalizedTimecodes,
              _normalizedTimecodes,
            ) &&
            (identical(other.projectSnapshot, projectSnapshot) ||
                other.projectSnapshot == projectSnapshot));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    text,
    const DeepCollectionEquality().hash(_normalizedTimecodes),
    projectSnapshot,
  );

  /// Create a copy of ValidatedCommand
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ValidatedCommandImplCopyWith<_$ValidatedCommandImpl> get copyWith =>
      __$$ValidatedCommandImplCopyWithImpl<_$ValidatedCommandImpl>(
        this,
        _$identity,
      );
}

abstract class _ValidatedCommand implements ValidatedCommand {
  const factory _ValidatedCommand({
    required final String text,
    required final Map<String, int> normalizedTimecodes,
    required final ProjectSnapshot projectSnapshot,
  }) = _$ValidatedCommandImpl;

  @override
  String get text;
  @override
  Map<String, int> get normalizedTimecodes;
  @override
  ProjectSnapshot get projectSnapshot;

  /// Create a copy of ValidatedCommand
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ValidatedCommandImplCopyWith<_$ValidatedCommandImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ProjectSnapshot {
  int get durationMs => throw _privateConstructorUsedError;
  int get width => throw _privateConstructorUsedError;
  int get height => throw _privateConstructorUsedError;
  double get fps => throw _privateConstructorUsedError;
  String get codec => throw _privateConstructorUsedError;
  bool get hasAudio => throw _privateConstructorUsedError;
  List<ClipSnapshot> get clips => throw _privateConstructorUsedError;

  /// Create a copy of ProjectSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProjectSnapshotCopyWith<ProjectSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProjectSnapshotCopyWith<$Res> {
  factory $ProjectSnapshotCopyWith(
    ProjectSnapshot value,
    $Res Function(ProjectSnapshot) then,
  ) = _$ProjectSnapshotCopyWithImpl<$Res, ProjectSnapshot>;
  @useResult
  $Res call({
    int durationMs,
    int width,
    int height,
    double fps,
    String codec,
    bool hasAudio,
    List<ClipSnapshot> clips,
  });
}

/// @nodoc
class _$ProjectSnapshotCopyWithImpl<$Res, $Val extends ProjectSnapshot>
    implements $ProjectSnapshotCopyWith<$Res> {
  _$ProjectSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProjectSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? durationMs = null,
    Object? width = null,
    Object? height = null,
    Object? fps = null,
    Object? codec = null,
    Object? hasAudio = null,
    Object? clips = null,
  }) {
    return _then(
      _value.copyWith(
            durationMs: null == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int,
            width: null == width
                ? _value.width
                : width // ignore: cast_nullable_to_non_nullable
                      as int,
            height: null == height
                ? _value.height
                : height // ignore: cast_nullable_to_non_nullable
                      as int,
            fps: null == fps
                ? _value.fps
                : fps // ignore: cast_nullable_to_non_nullable
                      as double,
            codec: null == codec
                ? _value.codec
                : codec // ignore: cast_nullable_to_non_nullable
                      as String,
            hasAudio: null == hasAudio
                ? _value.hasAudio
                : hasAudio // ignore: cast_nullable_to_non_nullable
                      as bool,
            clips: null == clips
                ? _value.clips
                : clips // ignore: cast_nullable_to_non_nullable
                      as List<ClipSnapshot>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProjectSnapshotImplCopyWith<$Res>
    implements $ProjectSnapshotCopyWith<$Res> {
  factory _$$ProjectSnapshotImplCopyWith(
    _$ProjectSnapshotImpl value,
    $Res Function(_$ProjectSnapshotImpl) then,
  ) = __$$ProjectSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int durationMs,
    int width,
    int height,
    double fps,
    String codec,
    bool hasAudio,
    List<ClipSnapshot> clips,
  });
}

/// @nodoc
class __$$ProjectSnapshotImplCopyWithImpl<$Res>
    extends _$ProjectSnapshotCopyWithImpl<$Res, _$ProjectSnapshotImpl>
    implements _$$ProjectSnapshotImplCopyWith<$Res> {
  __$$ProjectSnapshotImplCopyWithImpl(
    _$ProjectSnapshotImpl _value,
    $Res Function(_$ProjectSnapshotImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProjectSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? durationMs = null,
    Object? width = null,
    Object? height = null,
    Object? fps = null,
    Object? codec = null,
    Object? hasAudio = null,
    Object? clips = null,
  }) {
    return _then(
      _$ProjectSnapshotImpl(
        durationMs: null == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int,
        width: null == width
            ? _value.width
            : width // ignore: cast_nullable_to_non_nullable
                  as int,
        height: null == height
            ? _value.height
            : height // ignore: cast_nullable_to_non_nullable
                  as int,
        fps: null == fps
            ? _value.fps
            : fps // ignore: cast_nullable_to_non_nullable
                  as double,
        codec: null == codec
            ? _value.codec
            : codec // ignore: cast_nullable_to_non_nullable
                  as String,
        hasAudio: null == hasAudio
            ? _value.hasAudio
            : hasAudio // ignore: cast_nullable_to_non_nullable
                  as bool,
        clips: null == clips
            ? _value._clips
            : clips // ignore: cast_nullable_to_non_nullable
                  as List<ClipSnapshot>,
      ),
    );
  }
}

/// @nodoc

class _$ProjectSnapshotImpl implements _ProjectSnapshot {
  const _$ProjectSnapshotImpl({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.fps,
    required this.codec,
    required this.hasAudio,
    required final List<ClipSnapshot> clips,
  }) : _clips = clips;

  @override
  final int durationMs;
  @override
  final int width;
  @override
  final int height;
  @override
  final double fps;
  @override
  final String codec;
  @override
  final bool hasAudio;
  final List<ClipSnapshot> _clips;
  @override
  List<ClipSnapshot> get clips {
    if (_clips is EqualUnmodifiableListView) return _clips;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_clips);
  }

  @override
  String toString() {
    return 'ProjectSnapshot(durationMs: $durationMs, width: $width, height: $height, fps: $fps, codec: $codec, hasAudio: $hasAudio, clips: $clips)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectSnapshotImpl &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.fps, fps) || other.fps == fps) &&
            (identical(other.codec, codec) || other.codec == codec) &&
            (identical(other.hasAudio, hasAudio) ||
                other.hasAudio == hasAudio) &&
            const DeepCollectionEquality().equals(other._clips, _clips));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    durationMs,
    width,
    height,
    fps,
    codec,
    hasAudio,
    const DeepCollectionEquality().hash(_clips),
  );

  /// Create a copy of ProjectSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectSnapshotImplCopyWith<_$ProjectSnapshotImpl> get copyWith =>
      __$$ProjectSnapshotImplCopyWithImpl<_$ProjectSnapshotImpl>(
        this,
        _$identity,
      );
}

abstract class _ProjectSnapshot implements ProjectSnapshot {
  const factory _ProjectSnapshot({
    required final int durationMs,
    required final int width,
    required final int height,
    required final double fps,
    required final String codec,
    required final bool hasAudio,
    required final List<ClipSnapshot> clips,
  }) = _$ProjectSnapshotImpl;

  @override
  int get durationMs;
  @override
  int get width;
  @override
  int get height;
  @override
  double get fps;
  @override
  String get codec;
  @override
  bool get hasAudio;
  @override
  List<ClipSnapshot> get clips;

  /// Create a copy of ProjectSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProjectSnapshotImplCopyWith<_$ProjectSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ClipSnapshot {
  String get id => throw _privateConstructorUsedError;
  String get trackId => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  int get startMs => throw _privateConstructorUsedError;
  int get endMs => throw _privateConstructorUsedError;
  int get positionMs => throw _privateConstructorUsedError;

  /// Create a copy of ClipSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClipSnapshotCopyWith<ClipSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClipSnapshotCopyWith<$Res> {
  factory $ClipSnapshotCopyWith(
    ClipSnapshot value,
    $Res Function(ClipSnapshot) then,
  ) = _$ClipSnapshotCopyWithImpl<$Res, ClipSnapshot>;
  @useResult
  $Res call({
    String id,
    String trackId,
    String label,
    int startMs,
    int endMs,
    int positionMs,
  });
}

/// @nodoc
class _$ClipSnapshotCopyWithImpl<$Res, $Val extends ClipSnapshot>
    implements $ClipSnapshotCopyWith<$Res> {
  _$ClipSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ClipSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? trackId = null,
    Object? label = null,
    Object? startMs = null,
    Object? endMs = null,
    Object? positionMs = null,
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
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
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
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ClipSnapshotImplCopyWith<$Res>
    implements $ClipSnapshotCopyWith<$Res> {
  factory _$$ClipSnapshotImplCopyWith(
    _$ClipSnapshotImpl value,
    $Res Function(_$ClipSnapshotImpl) then,
  ) = __$$ClipSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String trackId,
    String label,
    int startMs,
    int endMs,
    int positionMs,
  });
}

/// @nodoc
class __$$ClipSnapshotImplCopyWithImpl<$Res>
    extends _$ClipSnapshotCopyWithImpl<$Res, _$ClipSnapshotImpl>
    implements _$$ClipSnapshotImplCopyWith<$Res> {
  __$$ClipSnapshotImplCopyWithImpl(
    _$ClipSnapshotImpl _value,
    $Res Function(_$ClipSnapshotImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ClipSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? trackId = null,
    Object? label = null,
    Object? startMs = null,
    Object? endMs = null,
    Object? positionMs = null,
  }) {
    return _then(
      _$ClipSnapshotImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        trackId: null == trackId
            ? _value.trackId
            : trackId // ignore: cast_nullable_to_non_nullable
                  as String,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
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
      ),
    );
  }
}

/// @nodoc

class _$ClipSnapshotImpl implements _ClipSnapshot {
  const _$ClipSnapshotImpl({
    required this.id,
    required this.trackId,
    required this.label,
    required this.startMs,
    required this.endMs,
    required this.positionMs,
  });

  @override
  final String id;
  @override
  final String trackId;
  @override
  final String label;
  @override
  final int startMs;
  @override
  final int endMs;
  @override
  final int positionMs;

  @override
  String toString() {
    return 'ClipSnapshot(id: $id, trackId: $trackId, label: $label, startMs: $startMs, endMs: $endMs, positionMs: $positionMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClipSnapshotImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.trackId, trackId) || other.trackId == trackId) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.startMs, startMs) || other.startMs == startMs) &&
            (identical(other.endMs, endMs) || other.endMs == endMs) &&
            (identical(other.positionMs, positionMs) ||
                other.positionMs == positionMs));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, trackId, label, startMs, endMs, positionMs);

  /// Create a copy of ClipSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClipSnapshotImplCopyWith<_$ClipSnapshotImpl> get copyWith =>
      __$$ClipSnapshotImplCopyWithImpl<_$ClipSnapshotImpl>(this, _$identity);
}

abstract class _ClipSnapshot implements ClipSnapshot {
  const factory _ClipSnapshot({
    required final String id,
    required final String trackId,
    required final String label,
    required final int startMs,
    required final int endMs,
    required final int positionMs,
  }) = _$ClipSnapshotImpl;

  @override
  String get id;
  @override
  String get trackId;
  @override
  String get label;
  @override
  int get startMs;
  @override
  int get endMs;
  @override
  int get positionMs;

  /// Create a copy of ClipSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClipSnapshotImplCopyWith<_$ClipSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$AgentRequest {
  String get systemPrompt => throw _privateConstructorUsedError;
  String get userCommand => throw _privateConstructorUsedError;
  String get schemaJson => throw _privateConstructorUsedError;
  int get timeoutSeconds => throw _privateConstructorUsedError;

  /// Create a copy of AgentRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AgentRequestCopyWith<AgentRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AgentRequestCopyWith<$Res> {
  factory $AgentRequestCopyWith(
    AgentRequest value,
    $Res Function(AgentRequest) then,
  ) = _$AgentRequestCopyWithImpl<$Res, AgentRequest>;
  @useResult
  $Res call({
    String systemPrompt,
    String userCommand,
    String schemaJson,
    int timeoutSeconds,
  });
}

/// @nodoc
class _$AgentRequestCopyWithImpl<$Res, $Val extends AgentRequest>
    implements $AgentRequestCopyWith<$Res> {
  _$AgentRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AgentRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? systemPrompt = null,
    Object? userCommand = null,
    Object? schemaJson = null,
    Object? timeoutSeconds = null,
  }) {
    return _then(
      _value.copyWith(
            systemPrompt: null == systemPrompt
                ? _value.systemPrompt
                : systemPrompt // ignore: cast_nullable_to_non_nullable
                      as String,
            userCommand: null == userCommand
                ? _value.userCommand
                : userCommand // ignore: cast_nullable_to_non_nullable
                      as String,
            schemaJson: null == schemaJson
                ? _value.schemaJson
                : schemaJson // ignore: cast_nullable_to_non_nullable
                      as String,
            timeoutSeconds: null == timeoutSeconds
                ? _value.timeoutSeconds
                : timeoutSeconds // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AgentRequestImplCopyWith<$Res>
    implements $AgentRequestCopyWith<$Res> {
  factory _$$AgentRequestImplCopyWith(
    _$AgentRequestImpl value,
    $Res Function(_$AgentRequestImpl) then,
  ) = __$$AgentRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String systemPrompt,
    String userCommand,
    String schemaJson,
    int timeoutSeconds,
  });
}

/// @nodoc
class __$$AgentRequestImplCopyWithImpl<$Res>
    extends _$AgentRequestCopyWithImpl<$Res, _$AgentRequestImpl>
    implements _$$AgentRequestImplCopyWith<$Res> {
  __$$AgentRequestImplCopyWithImpl(
    _$AgentRequestImpl _value,
    $Res Function(_$AgentRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AgentRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? systemPrompt = null,
    Object? userCommand = null,
    Object? schemaJson = null,
    Object? timeoutSeconds = null,
  }) {
    return _then(
      _$AgentRequestImpl(
        systemPrompt: null == systemPrompt
            ? _value.systemPrompt
            : systemPrompt // ignore: cast_nullable_to_non_nullable
                  as String,
        userCommand: null == userCommand
            ? _value.userCommand
            : userCommand // ignore: cast_nullable_to_non_nullable
                  as String,
        schemaJson: null == schemaJson
            ? _value.schemaJson
            : schemaJson // ignore: cast_nullable_to_non_nullable
                  as String,
        timeoutSeconds: null == timeoutSeconds
            ? _value.timeoutSeconds
            : timeoutSeconds // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$AgentRequestImpl implements _AgentRequest {
  const _$AgentRequestImpl({
    required this.systemPrompt,
    required this.userCommand,
    required this.schemaJson,
    required this.timeoutSeconds,
  });

  @override
  final String systemPrompt;
  @override
  final String userCommand;
  @override
  final String schemaJson;
  @override
  final int timeoutSeconds;

  @override
  String toString() {
    return 'AgentRequest(systemPrompt: $systemPrompt, userCommand: $userCommand, schemaJson: $schemaJson, timeoutSeconds: $timeoutSeconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AgentRequestImpl &&
            (identical(other.systemPrompt, systemPrompt) ||
                other.systemPrompt == systemPrompt) &&
            (identical(other.userCommand, userCommand) ||
                other.userCommand == userCommand) &&
            (identical(other.schemaJson, schemaJson) ||
                other.schemaJson == schemaJson) &&
            (identical(other.timeoutSeconds, timeoutSeconds) ||
                other.timeoutSeconds == timeoutSeconds));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    systemPrompt,
    userCommand,
    schemaJson,
    timeoutSeconds,
  );

  /// Create a copy of AgentRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AgentRequestImplCopyWith<_$AgentRequestImpl> get copyWith =>
      __$$AgentRequestImplCopyWithImpl<_$AgentRequestImpl>(this, _$identity);
}

abstract class _AgentRequest implements AgentRequest {
  const factory _AgentRequest({
    required final String systemPrompt,
    required final String userCommand,
    required final String schemaJson,
    required final int timeoutSeconds,
  }) = _$AgentRequestImpl;

  @override
  String get systemPrompt;
  @override
  String get userCommand;
  @override
  String get schemaJson;
  @override
  int get timeoutSeconds;

  /// Create a copy of AgentRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AgentRequestImplCopyWith<_$AgentRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ClarificationNeeded {
  String get question => throw _privateConstructorUsedError;
  List<String> get options => throw _privateConstructorUsedError;

  /// Create a copy of ClarificationNeeded
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ClarificationNeededCopyWith<ClarificationNeeded> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClarificationNeededCopyWith<$Res> {
  factory $ClarificationNeededCopyWith(
    ClarificationNeeded value,
    $Res Function(ClarificationNeeded) then,
  ) = _$ClarificationNeededCopyWithImpl<$Res, ClarificationNeeded>;
  @useResult
  $Res call({String question, List<String> options});
}

/// @nodoc
class _$ClarificationNeededCopyWithImpl<$Res, $Val extends ClarificationNeeded>
    implements $ClarificationNeededCopyWith<$Res> {
  _$ClarificationNeededCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ClarificationNeeded
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? question = null, Object? options = null}) {
    return _then(
      _value.copyWith(
            question: null == question
                ? _value.question
                : question // ignore: cast_nullable_to_non_nullable
                      as String,
            options: null == options
                ? _value.options
                : options // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ClarificationNeededImplCopyWith<$Res>
    implements $ClarificationNeededCopyWith<$Res> {
  factory _$$ClarificationNeededImplCopyWith(
    _$ClarificationNeededImpl value,
    $Res Function(_$ClarificationNeededImpl) then,
  ) = __$$ClarificationNeededImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String question, List<String> options});
}

/// @nodoc
class __$$ClarificationNeededImplCopyWithImpl<$Res>
    extends _$ClarificationNeededCopyWithImpl<$Res, _$ClarificationNeededImpl>
    implements _$$ClarificationNeededImplCopyWith<$Res> {
  __$$ClarificationNeededImplCopyWithImpl(
    _$ClarificationNeededImpl _value,
    $Res Function(_$ClarificationNeededImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ClarificationNeeded
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? question = null, Object? options = null}) {
    return _then(
      _$ClarificationNeededImpl(
        question: null == question
            ? _value.question
            : question // ignore: cast_nullable_to_non_nullable
                  as String,
        options: null == options
            ? _value._options
            : options // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc

class _$ClarificationNeededImpl implements _ClarificationNeeded {
  const _$ClarificationNeededImpl({
    required this.question,
    required final List<String> options,
  }) : _options = options;

  @override
  final String question;
  final List<String> _options;
  @override
  List<String> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

  @override
  String toString() {
    return 'ClarificationNeeded(question: $question, options: $options)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClarificationNeededImpl &&
            (identical(other.question, question) ||
                other.question == question) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    question,
    const DeepCollectionEquality().hash(_options),
  );

  /// Create a copy of ClarificationNeeded
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClarificationNeededImplCopyWith<_$ClarificationNeededImpl> get copyWith =>
      __$$ClarificationNeededImplCopyWithImpl<_$ClarificationNeededImpl>(
        this,
        _$identity,
      );
}

abstract class _ClarificationNeeded implements ClarificationNeeded {
  const factory _ClarificationNeeded({
    required final String question,
    required final List<String> options,
  }) = _$ClarificationNeededImpl;

  @override
  String get question;
  @override
  List<String> get options;

  /// Create a copy of ClarificationNeeded
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClarificationNeededImplCopyWith<_$ClarificationNeededImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
