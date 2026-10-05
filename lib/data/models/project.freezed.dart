// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Project {

 String get id; String get name; DateTime get createdAt; DateTime get updatedAt; List<String> get sourceMediaPaths; List<Track> get tracks; int get durationMs; String? get thumbnailPath; List<ChatMessage> get chatHistory; List<EditOperation> get editHistory; String get outputDir;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Project;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&const DeepCollectionEquality().equals(other.sourceMediaPaths, _this.sourceMediaPaths)&&const DeepCollectionEquality().equals(other.tracks, _this.tracks)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.thumbnailPath, _this.thumbnailPath) || other.thumbnailPath == _this.thumbnailPath)&&const DeepCollectionEquality().equals(other.chatHistory, _this.chatHistory)&&const DeepCollectionEquality().equals(other.editHistory, _this.editHistory)&&(identical(other.outputDir, _this.outputDir) || other.outputDir == _this.outputDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Project;
  return Object.hash(runtimeType,_this.id,_this.name,_this.createdAt,_this.updatedAt,const DeepCollectionEquality().hash(_this.sourceMediaPaths),const DeepCollectionEquality().hash(_this.tracks),_this.durationMs,_this.thumbnailPath,const DeepCollectionEquality().hash(_this.chatHistory),const DeepCollectionEquality().hash(_this.editHistory),_this.outputDir);
}

@override
String toString() {
  final _this = this as Project;
  return 'Project(id: ${_this.id}, name: ${_this.name}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, sourceMediaPaths: ${_this.sourceMediaPaths}, tracks: ${_this.tracks}, durationMs: ${_this.durationMs}, thumbnailPath: ${_this.thumbnailPath}, chatHistory: ${_this.chatHistory}, editHistory: ${_this.editHistory}, outputDir: ${_this.outputDir})';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime createdAt, DateTime updatedAt, List<String> sourceMediaPaths, List<Track> tracks, int durationMs, String? thumbnailPath, List<ChatMessage> chatHistory, List<EditOperation> editHistory, String outputDir
});




}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? sourceMediaPaths = null,Object? tracks = null,Object? durationMs = null,Object? thumbnailPath = freezed,Object? chatHistory = null,Object? editHistory = null,Object? outputDir = null,}) {
  return _then(Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,sourceMediaPaths: null == sourceMediaPaths ? _self.sourceMediaPaths : sourceMediaPaths // ignore: cast_nullable_to_non_nullable
as List<String>,tracks: null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<Track>,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,thumbnailPath: freezed == thumbnailPath ? _self.thumbnailPath : thumbnailPath // ignore: cast_nullable_to_non_nullable
as String?,chatHistory: null == chatHistory ? _self.chatHistory : chatHistory // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,editHistory: null == editHistory ? _self.editHistory : editHistory // ignore: cast_nullable_to_non_nullable
as List<EditOperation>,outputDir: null == outputDir ? _self.outputDir : outputDir // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Project].
extension ProjectPatterns on Project {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Project value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Project value)  $default,){
final _that = this;
switch (_that) {
case _Project():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Project value)?  $default,){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime createdAt,  DateTime updatedAt,  List<String> sourceMediaPaths,  List<Track> tracks,  int durationMs,  String? thumbnailPath,  List<ChatMessage> chatHistory,  List<EditOperation> editHistory,  String outputDir)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.updatedAt,_that.sourceMediaPaths,_that.tracks,_that.durationMs,_that.thumbnailPath,_that.chatHistory,_that.editHistory,_that.outputDir);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime createdAt,  DateTime updatedAt,  List<String> sourceMediaPaths,  List<Track> tracks,  int durationMs,  String? thumbnailPath,  List<ChatMessage> chatHistory,  List<EditOperation> editHistory,  String outputDir)  $default,) {final _that = this;
switch (_that) {
case _Project():
return $default(_that.id,_that.name,_that.createdAt,_that.updatedAt,_that.sourceMediaPaths,_that.tracks,_that.durationMs,_that.thumbnailPath,_that.chatHistory,_that.editHistory,_that.outputDir);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime createdAt,  DateTime updatedAt,  List<String> sourceMediaPaths,  List<Track> tracks,  int durationMs,  String? thumbnailPath,  List<ChatMessage> chatHistory,  List<EditOperation> editHistory,  String outputDir)?  $default,) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.updatedAt,_that.sourceMediaPaths,_that.tracks,_that.durationMs,_that.thumbnailPath,_that.chatHistory,_that.editHistory,_that.outputDir);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Project implements Project {
  const _Project({required this.id, required this.name, required this.createdAt, required this.updatedAt,  List<String> sourceMediaPaths = const [],  List<Track> tracks = const [], this.durationMs = 0, this.thumbnailPath,  List<ChatMessage> chatHistory = const [],  List<EditOperation> editHistory = const [], this.outputDir = ''}): _sourceMediaPaths = sourceMediaPaths,_tracks = tracks,_chatHistory = chatHistory,_editHistory = editHistory;
  factory _Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

@override final  String id;
@override final  String name;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
 final  List<String> _sourceMediaPaths;
@override@JsonKey() List<String> get sourceMediaPaths {
  if (_sourceMediaPaths is EqualUnmodifiableListView) return _sourceMediaPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sourceMediaPaths);
}

 final  List<Track> _tracks;
@override@JsonKey() List<Track> get tracks {
  if (_tracks is EqualUnmodifiableListView) return _tracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tracks);
}

@override@JsonKey() final  int durationMs;
@override final  String? thumbnailPath;
 final  List<ChatMessage> _chatHistory;
@override@JsonKey() List<ChatMessage> get chatHistory {
  if (_chatHistory is EqualUnmodifiableListView) return _chatHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chatHistory);
}

 final  List<EditOperation> _editHistory;
@override@JsonKey() List<EditOperation> get editHistory {
  if (_editHistory is EqualUnmodifiableListView) return _editHistory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_editHistory);
}

@override@JsonKey() final  String outputDir;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.sourceMediaPaths, _sourceMediaPaths)&&const DeepCollectionEquality().equals(other.tracks, _tracks)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.thumbnailPath, thumbnailPath) || other.thumbnailPath == thumbnailPath)&&const DeepCollectionEquality().equals(other.chatHistory, _chatHistory)&&const DeepCollectionEquality().equals(other.editHistory, _editHistory)&&(identical(other.outputDir, outputDir) || other.outputDir == outputDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,createdAt,updatedAt,const DeepCollectionEquality().hash(_sourceMediaPaths),const DeepCollectionEquality().hash(_tracks),durationMs,thumbnailPath,const DeepCollectionEquality().hash(_chatHistory),const DeepCollectionEquality().hash(_editHistory),outputDir);
}

@override
String toString() {
    return 'Project(id: $id, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, sourceMediaPaths: $sourceMediaPaths, tracks: $tracks, durationMs: $durationMs, thumbnailPath: $thumbnailPath, chatHistory: $chatHistory, editHistory: $editHistory, outputDir: $outputDir)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime createdAt, DateTime updatedAt, List<String> sourceMediaPaths, List<Track> tracks, int durationMs, String? thumbnailPath, List<ChatMessage> chatHistory, List<EditOperation> editHistory, String outputDir
});




}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? sourceMediaPaths = null,Object? tracks = null,Object? durationMs = null,Object? thumbnailPath = freezed,Object? chatHistory = null,Object? editHistory = null,Object? outputDir = null,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,sourceMediaPaths: null == sourceMediaPaths ? _self._sourceMediaPaths : sourceMediaPaths // ignore: cast_nullable_to_non_nullable
as List<String>,tracks: null == tracks ? _self._tracks : tracks // ignore: cast_nullable_to_non_nullable
as List<Track>,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,thumbnailPath: freezed == thumbnailPath ? _self.thumbnailPath : thumbnailPath // ignore: cast_nullable_to_non_nullable
as String?,chatHistory: null == chatHistory ? _self._chatHistory : chatHistory // ignore: cast_nullable_to_non_nullable
as List<ChatMessage>,editHistory: null == editHistory ? _self._editHistory : editHistory // ignore: cast_nullable_to_non_nullable
as List<EditOperation>,outputDir: null == outputDir ? _self.outputDir : outputDir // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
