// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Project _$ProjectFromJson(Map<String, dynamic> json) {
  return _Project.fromJson(json);
}

/// @nodoc
mixin _$Project {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  List<String> get sourceMediaPaths => throw _privateConstructorUsedError;
  List<Track> get tracks => throw _privateConstructorUsedError;
  int get durationMs => throw _privateConstructorUsedError;
  String? get thumbnailPath => throw _privateConstructorUsedError;
  List<ChatMessage> get chatHistory => throw _privateConstructorUsedError;
  List<EditOperation> get editHistory => throw _privateConstructorUsedError;
  String get outputDir => throw _privateConstructorUsedError;

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProjectCopyWith<Project> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProjectCopyWith<$Res> {
  factory $ProjectCopyWith(Project value, $Res Function(Project) then) =
      _$ProjectCopyWithImpl<$Res, Project>;
  @useResult
  $Res call({
    String id,
    String name,
    DateTime createdAt,
    DateTime updatedAt,
    List<String> sourceMediaPaths,
    List<Track> tracks,
    int durationMs,
    String? thumbnailPath,
    List<ChatMessage> chatHistory,
    List<EditOperation> editHistory,
    String outputDir,
  });
}

/// @nodoc
class _$ProjectCopyWithImpl<$Res, $Val extends Project>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? sourceMediaPaths = null,
    Object? tracks = null,
    Object? durationMs = null,
    Object? thumbnailPath = freezed,
    Object? chatHistory = null,
    Object? editHistory = null,
    Object? outputDir = null,
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
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            sourceMediaPaths: null == sourceMediaPaths
                ? _value.sourceMediaPaths
                : sourceMediaPaths // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            tracks: null == tracks
                ? _value.tracks
                : tracks // ignore: cast_nullable_to_non_nullable
                      as List<Track>,
            durationMs: null == durationMs
                ? _value.durationMs
                : durationMs // ignore: cast_nullable_to_non_nullable
                      as int,
            thumbnailPath: freezed == thumbnailPath
                ? _value.thumbnailPath
                : thumbnailPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            chatHistory: null == chatHistory
                ? _value.chatHistory
                : chatHistory // ignore: cast_nullable_to_non_nullable
                      as List<ChatMessage>,
            editHistory: null == editHistory
                ? _value.editHistory
                : editHistory // ignore: cast_nullable_to_non_nullable
                      as List<EditOperation>,
            outputDir: null == outputDir
                ? _value.outputDir
                : outputDir // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProjectImplCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$$ProjectImplCopyWith(
    _$ProjectImpl value,
    $Res Function(_$ProjectImpl) then,
  ) = __$$ProjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    DateTime createdAt,
    DateTime updatedAt,
    List<String> sourceMediaPaths,
    List<Track> tracks,
    int durationMs,
    String? thumbnailPath,
    List<ChatMessage> chatHistory,
    List<EditOperation> editHistory,
    String outputDir,
  });
}

/// @nodoc
class __$$ProjectImplCopyWithImpl<$Res>
    extends _$ProjectCopyWithImpl<$Res, _$ProjectImpl>
    implements _$$ProjectImplCopyWith<$Res> {
  __$$ProjectImplCopyWithImpl(
    _$ProjectImpl _value,
    $Res Function(_$ProjectImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? sourceMediaPaths = null,
    Object? tracks = null,
    Object? durationMs = null,
    Object? thumbnailPath = freezed,
    Object? chatHistory = null,
    Object? editHistory = null,
    Object? outputDir = null,
  }) {
    return _then(
      _$ProjectImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        sourceMediaPaths: null == sourceMediaPaths
            ? _value._sourceMediaPaths
            : sourceMediaPaths // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        tracks: null == tracks
            ? _value._tracks
            : tracks // ignore: cast_nullable_to_non_nullable
                  as List<Track>,
        durationMs: null == durationMs
            ? _value.durationMs
            : durationMs // ignore: cast_nullable_to_non_nullable
                  as int,
        thumbnailPath: freezed == thumbnailPath
            ? _value.thumbnailPath
            : thumbnailPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        chatHistory: null == chatHistory
            ? _value._chatHistory
            : chatHistory // ignore: cast_nullable_to_non_nullable
                  as List<ChatMessage>,
        editHistory: null == editHistory
            ? _value._editHistory
            : editHistory // ignore: cast_nullable_to_non_nullable
                  as List<EditOperation>,
        outputDir: null == outputDir
            ? _value.outputDir
            : outputDir // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProjectImpl implements _Project {
  const _$ProjectImpl({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    final List<String> sourceMediaPaths = const [],
    final List<Track> tracks = const [],
    this.durationMs = 0,
    this.thumbnailPath,
    final List<ChatMessage> chatHistory = const [],
    final List<EditOperation> editHistory = const [],
    this.outputDir = '',
  }) : _sourceMediaPaths = sourceMediaPaths,
       _tracks = tracks,
       _chatHistory = chatHistory,
       _editHistory = editHistory;

  factory _$ProjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final List<String> _sourceMediaPaths;
  @override
  @JsonKey()
  List<String> get sourceMediaPaths {
    if (_sourceMediaPaths is EqualUnmodifiableListView)
      return _sourceMediaPaths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sourceMediaPaths);
  }

  final List<Track> _tracks;
  @override
  @JsonKey()
  List<Track> get tracks {
    if (_tracks is EqualUnmodifiableListView) return _tracks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tracks);
  }

  @override
  @JsonKey()
  final int durationMs;
  @override
  final String? thumbnailPath;
  final List<ChatMessage> _chatHistory;
  @override
  @JsonKey()
  List<ChatMessage> get chatHistory {
    if (_chatHistory is EqualUnmodifiableListView) return _chatHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chatHistory);
  }

  final List<EditOperation> _editHistory;
  @override
  @JsonKey()
  List<EditOperation> get editHistory {
    if (_editHistory is EqualUnmodifiableListView) return _editHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_editHistory);
  }

  @override
  @JsonKey()
  final String outputDir;

  @override
  String toString() {
    return 'Project(id: $id, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, sourceMediaPaths: $sourceMediaPaths, tracks: $tracks, durationMs: $durationMs, thumbnailPath: $thumbnailPath, chatHistory: $chatHistory, editHistory: $editHistory, outputDir: $outputDir)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(
              other._sourceMediaPaths,
              _sourceMediaPaths,
            ) &&
            const DeepCollectionEquality().equals(other._tracks, _tracks) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.thumbnailPath, thumbnailPath) ||
                other.thumbnailPath == thumbnailPath) &&
            const DeepCollectionEquality().equals(
              other._chatHistory,
              _chatHistory,
            ) &&
            const DeepCollectionEquality().equals(
              other._editHistory,
              _editHistory,
            ) &&
            (identical(other.outputDir, outputDir) ||
                other.outputDir == outputDir));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    createdAt,
    updatedAt,
    const DeepCollectionEquality().hash(_sourceMediaPaths),
    const DeepCollectionEquality().hash(_tracks),
    durationMs,
    thumbnailPath,
    const DeepCollectionEquality().hash(_chatHistory),
    const DeepCollectionEquality().hash(_editHistory),
    outputDir,
  );

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProjectImplCopyWith<_$ProjectImpl> get copyWith =>
      __$$ProjectImplCopyWithImpl<_$ProjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProjectImplToJson(this);
  }
}

abstract class _Project implements Project {
  const factory _Project({
    required final String id,
    required final String name,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final List<String> sourceMediaPaths,
    final List<Track> tracks,
    final int durationMs,
    final String? thumbnailPath,
    final List<ChatMessage> chatHistory,
    final List<EditOperation> editHistory,
    final String outputDir,
  }) = _$ProjectImpl;

  factory _Project.fromJson(Map<String, dynamic> json) = _$ProjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  List<String> get sourceMediaPaths;
  @override
  List<Track> get tracks;
  @override
  int get durationMs;
  @override
  String? get thumbnailPath;
  @override
  List<ChatMessage> get chatHistory;
  @override
  List<EditOperation> get editHistory;
  @override
  String get outputDir;

  /// Create a copy of Project
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProjectImplCopyWith<_$ProjectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
