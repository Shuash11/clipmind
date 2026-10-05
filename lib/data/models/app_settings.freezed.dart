// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppSettings {

 String get activeProviderId;@Deprecated('Unused since the provider-profile system; model selection ' 'lives in the provider profile (selectedModelId). Kept for the ' 'legacy-settings migration and JSON round-trip.') String get activeModel; String get ollamaEndpoint; ThemeModePreference get theme; Map<String, String> get outputFormatDefaults; bool get confirmAgentEdits; bool get planEditsBeforeApply; String get whisperBinaryPath; String get whisperModelPath; String get lastSeenVersion;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);

  /// Serializes this AppSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AppSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&(identical(other.activeProviderId, _this.activeProviderId) || other.activeProviderId == _this.activeProviderId)&&(identical(other.activeModel, _this.activeModel) || other.activeModel == _this.activeModel)&&(identical(other.ollamaEndpoint, _this.ollamaEndpoint) || other.ollamaEndpoint == _this.ollamaEndpoint)&&(identical(other.theme, _this.theme) || other.theme == _this.theme)&&const DeepCollectionEquality().equals(other.outputFormatDefaults, _this.outputFormatDefaults)&&(identical(other.confirmAgentEdits, _this.confirmAgentEdits) || other.confirmAgentEdits == _this.confirmAgentEdits)&&(identical(other.planEditsBeforeApply, _this.planEditsBeforeApply) || other.planEditsBeforeApply == _this.planEditsBeforeApply)&&(identical(other.whisperBinaryPath, _this.whisperBinaryPath) || other.whisperBinaryPath == _this.whisperBinaryPath)&&(identical(other.whisperModelPath, _this.whisperModelPath) || other.whisperModelPath == _this.whisperModelPath)&&(identical(other.lastSeenVersion, _this.lastSeenVersion) || other.lastSeenVersion == _this.lastSeenVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AppSettings;
  return Object.hash(runtimeType,_this.activeProviderId,_this.activeModel,_this.ollamaEndpoint,_this.theme,const DeepCollectionEquality().hash(_this.outputFormatDefaults),_this.confirmAgentEdits,_this.planEditsBeforeApply,_this.whisperBinaryPath,_this.whisperModelPath,_this.lastSeenVersion);
}

@override
String toString() {
  final _this = this as AppSettings;
  return 'AppSettings(activeProviderId: ${_this.activeProviderId}, activeModel: ${_this.activeModel}, ollamaEndpoint: ${_this.ollamaEndpoint}, theme: ${_this.theme}, outputFormatDefaults: ${_this.outputFormatDefaults}, confirmAgentEdits: ${_this.confirmAgentEdits}, planEditsBeforeApply: ${_this.planEditsBeforeApply}, whisperBinaryPath: ${_this.whisperBinaryPath}, whisperModelPath: ${_this.whisperModelPath}, lastSeenVersion: ${_this.lastSeenVersion})';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 String activeProviderId,@Deprecated('Unused since the provider-profile system; model selection ' 'lives in the provider profile (selectedModelId). Kept for the ' 'legacy-settings migration and JSON round-trip.') String activeModel, String ollamaEndpoint, ThemeModePreference theme, Map<String, String> outputFormatDefaults, bool confirmAgentEdits, bool planEditsBeforeApply, String whisperBinaryPath, String whisperModelPath, String lastSeenVersion
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? activeProviderId = null,Object? activeModel = null,Object? ollamaEndpoint = null,Object? theme = null,Object? outputFormatDefaults = null,Object? confirmAgentEdits = null,Object? planEditsBeforeApply = null,Object? whisperBinaryPath = null,Object? whisperModelPath = null,Object? lastSeenVersion = null,}) {
  return _then(AppSettings(
activeProviderId: null == activeProviderId ? _self.activeProviderId : activeProviderId // ignore: cast_nullable_to_non_nullable
as String,activeModel: null == activeModel ? _self.activeModel : activeModel // ignore: cast_nullable_to_non_nullable
as String,ollamaEndpoint: null == ollamaEndpoint ? _self.ollamaEndpoint : ollamaEndpoint // ignore: cast_nullable_to_non_nullable
as String,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemeModePreference,outputFormatDefaults: null == outputFormatDefaults ? _self.outputFormatDefaults : outputFormatDefaults // ignore: cast_nullable_to_non_nullable
as Map<String, String>,confirmAgentEdits: null == confirmAgentEdits ? _self.confirmAgentEdits : confirmAgentEdits // ignore: cast_nullable_to_non_nullable
as bool,planEditsBeforeApply: null == planEditsBeforeApply ? _self.planEditsBeforeApply : planEditsBeforeApply // ignore: cast_nullable_to_non_nullable
as bool,whisperBinaryPath: null == whisperBinaryPath ? _self.whisperBinaryPath : whisperBinaryPath // ignore: cast_nullable_to_non_nullable
as String,whisperModelPath: null == whisperModelPath ? _self.whisperModelPath : whisperModelPath // ignore: cast_nullable_to_non_nullable
as String,lastSeenVersion: null == lastSeenVersion ? _self.lastSeenVersion : lastSeenVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String activeProviderId, @Deprecated('Unused since the provider-profile system; model selection ' 'lives in the provider profile (selectedModelId). Kept for the ' 'legacy-settings migration and JSON round-trip.')  String activeModel,  String ollamaEndpoint,  ThemeModePreference theme,  Map<String, String> outputFormatDefaults,  bool confirmAgentEdits,  bool planEditsBeforeApply,  String whisperBinaryPath,  String whisperModelPath,  String lastSeenVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.activeProviderId,_that.activeModel,_that.ollamaEndpoint,_that.theme,_that.outputFormatDefaults,_that.confirmAgentEdits,_that.planEditsBeforeApply,_that.whisperBinaryPath,_that.whisperModelPath,_that.lastSeenVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String activeProviderId, @Deprecated('Unused since the provider-profile system; model selection ' 'lives in the provider profile (selectedModelId). Kept for the ' 'legacy-settings migration and JSON round-trip.')  String activeModel,  String ollamaEndpoint,  ThemeModePreference theme,  Map<String, String> outputFormatDefaults,  bool confirmAgentEdits,  bool planEditsBeforeApply,  String whisperBinaryPath,  String whisperModelPath,  String lastSeenVersion)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.activeProviderId,_that.activeModel,_that.ollamaEndpoint,_that.theme,_that.outputFormatDefaults,_that.confirmAgentEdits,_that.planEditsBeforeApply,_that.whisperBinaryPath,_that.whisperModelPath,_that.lastSeenVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String activeProviderId, @Deprecated('Unused since the provider-profile system; model selection ' 'lives in the provider profile (selectedModelId). Kept for the ' 'legacy-settings migration and JSON round-trip.')  String activeModel,  String ollamaEndpoint,  ThemeModePreference theme,  Map<String, String> outputFormatDefaults,  bool confirmAgentEdits,  bool planEditsBeforeApply,  String whisperBinaryPath,  String whisperModelPath,  String lastSeenVersion)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.activeProviderId,_that.activeModel,_that.ollamaEndpoint,_that.theme,_that.outputFormatDefaults,_that.confirmAgentEdits,_that.planEditsBeforeApply,_that.whisperBinaryPath,_that.whisperModelPath,_that.lastSeenVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppSettings implements AppSettings {
  const _AppSettings({this.activeProviderId = 'ollama', @Deprecated('Unused since the provider-profile system; model selection ' 'lives in the provider profile (selectedModelId). Kept for the ' 'legacy-settings migration and JSON round-trip.') this.activeModel = '', this.ollamaEndpoint = 'http://localhost:11434', this.theme = ThemeModePreference.dark,  Map<String, String> outputFormatDefaults = const {}, this.confirmAgentEdits = false, this.planEditsBeforeApply = false, this.whisperBinaryPath = '', this.whisperModelPath = '', this.lastSeenVersion = ''}): _outputFormatDefaults = outputFormatDefaults;
  factory _AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);

@override@JsonKey() final  String activeProviderId;
@override@JsonKey()@Deprecated('Unused since the provider-profile system; model selection ' 'lives in the provider profile (selectedModelId). Kept for the ' 'legacy-settings migration and JSON round-trip.') final  String activeModel;
@override@JsonKey() final  String ollamaEndpoint;
@override@JsonKey() final  ThemeModePreference theme;
 final  Map<String, String> _outputFormatDefaults;
@override@JsonKey() Map<String, String> get outputFormatDefaults {
  if (_outputFormatDefaults is EqualUnmodifiableMapView) return _outputFormatDefaults;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_outputFormatDefaults);
}

@override@JsonKey() final  bool confirmAgentEdits;
@override@JsonKey() final  bool planEditsBeforeApply;
@override@JsonKey() final  String whisperBinaryPath;
@override@JsonKey() final  String whisperModelPath;
@override@JsonKey() final  String lastSeenVersion;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&(identical(other.activeProviderId, activeProviderId) || other.activeProviderId == activeProviderId)&&(identical(other.activeModel, activeModel) || other.activeModel == activeModel)&&(identical(other.ollamaEndpoint, ollamaEndpoint) || other.ollamaEndpoint == ollamaEndpoint)&&(identical(other.theme, theme) || other.theme == theme)&&const DeepCollectionEquality().equals(other.outputFormatDefaults, _outputFormatDefaults)&&(identical(other.confirmAgentEdits, confirmAgentEdits) || other.confirmAgentEdits == confirmAgentEdits)&&(identical(other.planEditsBeforeApply, planEditsBeforeApply) || other.planEditsBeforeApply == planEditsBeforeApply)&&(identical(other.whisperBinaryPath, whisperBinaryPath) || other.whisperBinaryPath == whisperBinaryPath)&&(identical(other.whisperModelPath, whisperModelPath) || other.whisperModelPath == whisperModelPath)&&(identical(other.lastSeenVersion, lastSeenVersion) || other.lastSeenVersion == lastSeenVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,activeProviderId,activeModel,ollamaEndpoint,theme,const DeepCollectionEquality().hash(_outputFormatDefaults),confirmAgentEdits,planEditsBeforeApply,whisperBinaryPath,whisperModelPath,lastSeenVersion);
}

@override
String toString() {
    return 'AppSettings(activeProviderId: $activeProviderId, activeModel: $activeModel, ollamaEndpoint: $ollamaEndpoint, theme: $theme, outputFormatDefaults: $outputFormatDefaults, confirmAgentEdits: $confirmAgentEdits, planEditsBeforeApply: $planEditsBeforeApply, whisperBinaryPath: $whisperBinaryPath, whisperModelPath: $whisperModelPath, lastSeenVersion: $lastSeenVersion)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 String activeProviderId,@Deprecated('Unused since the provider-profile system; model selection ' 'lives in the provider profile (selectedModelId). Kept for the ' 'legacy-settings migration and JSON round-trip.') String activeModel, String ollamaEndpoint, ThemeModePreference theme, Map<String, String> outputFormatDefaults, bool confirmAgentEdits, bool planEditsBeforeApply, String whisperBinaryPath, String whisperModelPath, String lastSeenVersion
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? activeProviderId = null,Object? activeModel = null,Object? ollamaEndpoint = null,Object? theme = null,Object? outputFormatDefaults = null,Object? confirmAgentEdits = null,Object? planEditsBeforeApply = null,Object? whisperBinaryPath = null,Object? whisperModelPath = null,Object? lastSeenVersion = null,}) {
  return _then(_AppSettings(
activeProviderId: null == activeProviderId ? _self.activeProviderId : activeProviderId // ignore: cast_nullable_to_non_nullable
as String,activeModel: null == activeModel ? _self.activeModel : activeModel // ignore: cast_nullable_to_non_nullable
as String,ollamaEndpoint: null == ollamaEndpoint ? _self.ollamaEndpoint : ollamaEndpoint // ignore: cast_nullable_to_non_nullable
as String,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemeModePreference,outputFormatDefaults: null == outputFormatDefaults ? _self._outputFormatDefaults : outputFormatDefaults // ignore: cast_nullable_to_non_nullable
as Map<String, String>,confirmAgentEdits: null == confirmAgentEdits ? _self.confirmAgentEdits : confirmAgentEdits // ignore: cast_nullable_to_non_nullable
as bool,planEditsBeforeApply: null == planEditsBeforeApply ? _self.planEditsBeforeApply : planEditsBeforeApply // ignore: cast_nullable_to_non_nullable
as bool,whisperBinaryPath: null == whisperBinaryPath ? _self.whisperBinaryPath : whisperBinaryPath // ignore: cast_nullable_to_non_nullable
as String,whisperModelPath: null == whisperModelPath ? _self.whisperModelPath : whisperModelPath // ignore: cast_nullable_to_non_nullable
as String,lastSeenVersion: null == lastSeenVersion ? _self.lastSeenVersion : lastSeenVersion // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
