// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) {
  return _AppSettings.fromJson(json);
}

/// @nodoc
mixin _$AppSettings {
  String get activeProviderId => throw _privateConstructorUsedError;
  @Deprecated(
    'Unused since the provider-profile system; model selection '
    'lives in the provider profile (selectedModelId). Kept for the '
    'legacy-settings migration and JSON round-trip.',
  )
  String get activeModel => throw _privateConstructorUsedError;
  String get ollamaEndpoint => throw _privateConstructorUsedError;
  ThemeModePreference get theme => throw _privateConstructorUsedError;
  Map<String, String> get outputFormatDefaults =>
      throw _privateConstructorUsedError;
  bool get confirmAgentEdits => throw _privateConstructorUsedError;
  bool get planEditsBeforeApply => throw _privateConstructorUsedError;
  String get whisperBinaryPath => throw _privateConstructorUsedError;
  String get whisperModelPath => throw _privateConstructorUsedError;
  String get lastSeenVersion => throw _privateConstructorUsedError;

  /// Serializes this AppSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppSettingsCopyWith<AppSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppSettingsCopyWith<$Res> {
  factory $AppSettingsCopyWith(
    AppSettings value,
    $Res Function(AppSettings) then,
  ) = _$AppSettingsCopyWithImpl<$Res, AppSettings>;
  @useResult
  $Res call({
    String activeProviderId,
    @Deprecated(
      'Unused since the provider-profile system; model selection '
      'lives in the provider profile (selectedModelId). Kept for the '
      'legacy-settings migration and JSON round-trip.',
    )
    String activeModel,
    String ollamaEndpoint,
    ThemeModePreference theme,
    Map<String, String> outputFormatDefaults,
    bool confirmAgentEdits,
    bool planEditsBeforeApply,
    String whisperBinaryPath,
    String whisperModelPath,
    String lastSeenVersion,
  });
}

/// @nodoc
class _$AppSettingsCopyWithImpl<$Res, $Val extends AppSettings>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeProviderId = null,
    Object? activeModel = null,
    Object? ollamaEndpoint = null,
    Object? theme = null,
    Object? outputFormatDefaults = null,
    Object? confirmAgentEdits = null,
    Object? planEditsBeforeApply = null,
    Object? whisperBinaryPath = null,
    Object? whisperModelPath = null,
    Object? lastSeenVersion = null,
  }) {
    return _then(
      _value.copyWith(
            activeProviderId: null == activeProviderId
                ? _value.activeProviderId
                : activeProviderId // ignore: cast_nullable_to_non_nullable
                      as String,
            activeModel: null == activeModel
                ? _value.activeModel
                : activeModel // ignore: cast_nullable_to_non_nullable
                      as String,
            ollamaEndpoint: null == ollamaEndpoint
                ? _value.ollamaEndpoint
                : ollamaEndpoint // ignore: cast_nullable_to_non_nullable
                      as String,
            theme: null == theme
                ? _value.theme
                : theme // ignore: cast_nullable_to_non_nullable
                      as ThemeModePreference,
            outputFormatDefaults: null == outputFormatDefaults
                ? _value.outputFormatDefaults
                : outputFormatDefaults // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
            confirmAgentEdits: null == confirmAgentEdits
                ? _value.confirmAgentEdits
                : confirmAgentEdits // ignore: cast_nullable_to_non_nullable
                      as bool,
            planEditsBeforeApply: null == planEditsBeforeApply
                ? _value.planEditsBeforeApply
                : planEditsBeforeApply // ignore: cast_nullable_to_non_nullable
                      as bool,
            whisperBinaryPath: null == whisperBinaryPath
                ? _value.whisperBinaryPath
                : whisperBinaryPath // ignore: cast_nullable_to_non_nullable
                      as String,
            whisperModelPath: null == whisperModelPath
                ? _value.whisperModelPath
                : whisperModelPath // ignore: cast_nullable_to_non_nullable
                      as String,
            lastSeenVersion: null == lastSeenVersion
                ? _value.lastSeenVersion
                : lastSeenVersion // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppSettingsImplCopyWith<$Res>
    implements $AppSettingsCopyWith<$Res> {
  factory _$$AppSettingsImplCopyWith(
    _$AppSettingsImpl value,
    $Res Function(_$AppSettingsImpl) then,
  ) = __$$AppSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String activeProviderId,
    @Deprecated(
      'Unused since the provider-profile system; model selection '
      'lives in the provider profile (selectedModelId). Kept for the '
      'legacy-settings migration and JSON round-trip.',
    )
    String activeModel,
    String ollamaEndpoint,
    ThemeModePreference theme,
    Map<String, String> outputFormatDefaults,
    bool confirmAgentEdits,
    bool planEditsBeforeApply,
    String whisperBinaryPath,
    String whisperModelPath,
    String lastSeenVersion,
  });
}

/// @nodoc
class __$$AppSettingsImplCopyWithImpl<$Res>
    extends _$AppSettingsCopyWithImpl<$Res, _$AppSettingsImpl>
    implements _$$AppSettingsImplCopyWith<$Res> {
  __$$AppSettingsImplCopyWithImpl(
    _$AppSettingsImpl _value,
    $Res Function(_$AppSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeProviderId = null,
    Object? activeModel = null,
    Object? ollamaEndpoint = null,
    Object? theme = null,
    Object? outputFormatDefaults = null,
    Object? confirmAgentEdits = null,
    Object? planEditsBeforeApply = null,
    Object? whisperBinaryPath = null,
    Object? whisperModelPath = null,
    Object? lastSeenVersion = null,
  }) {
    return _then(
      _$AppSettingsImpl(
        activeProviderId: null == activeProviderId
            ? _value.activeProviderId
            : activeProviderId // ignore: cast_nullable_to_non_nullable
                  as String,
        activeModel: null == activeModel
            ? _value.activeModel
            : activeModel // ignore: cast_nullable_to_non_nullable
                  as String,
        ollamaEndpoint: null == ollamaEndpoint
            ? _value.ollamaEndpoint
            : ollamaEndpoint // ignore: cast_nullable_to_non_nullable
                  as String,
        theme: null == theme
            ? _value.theme
            : theme // ignore: cast_nullable_to_non_nullable
                  as ThemeModePreference,
        outputFormatDefaults: null == outputFormatDefaults
            ? _value._outputFormatDefaults
            : outputFormatDefaults // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
        confirmAgentEdits: null == confirmAgentEdits
            ? _value.confirmAgentEdits
            : confirmAgentEdits // ignore: cast_nullable_to_non_nullable
                  as bool,
        planEditsBeforeApply: null == planEditsBeforeApply
            ? _value.planEditsBeforeApply
            : planEditsBeforeApply // ignore: cast_nullable_to_non_nullable
                  as bool,
        whisperBinaryPath: null == whisperBinaryPath
            ? _value.whisperBinaryPath
            : whisperBinaryPath // ignore: cast_nullable_to_non_nullable
                  as String,
        whisperModelPath: null == whisperModelPath
            ? _value.whisperModelPath
            : whisperModelPath // ignore: cast_nullable_to_non_nullable
                  as String,
        lastSeenVersion: null == lastSeenVersion
            ? _value.lastSeenVersion
            : lastSeenVersion // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppSettingsImpl implements _AppSettings {
  const _$AppSettingsImpl({
    this.activeProviderId = 'ollama',
    @Deprecated(
      'Unused since the provider-profile system; model selection '
      'lives in the provider profile (selectedModelId). Kept for the '
      'legacy-settings migration and JSON round-trip.',
    )
    this.activeModel = '',
    this.ollamaEndpoint = 'http://localhost:11434',
    this.theme = ThemeModePreference.dark,
    final Map<String, String> outputFormatDefaults = const {},
    this.confirmAgentEdits = false,
    this.planEditsBeforeApply = false,
    this.whisperBinaryPath = '',
    this.whisperModelPath = '',
    this.lastSeenVersion = '',
  }) : _outputFormatDefaults = outputFormatDefaults;

  factory _$AppSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppSettingsImplFromJson(json);

  @override
  @JsonKey()
  final String activeProviderId;
  @override
  @JsonKey()
  @Deprecated(
    'Unused since the provider-profile system; model selection '
    'lives in the provider profile (selectedModelId). Kept for the '
    'legacy-settings migration and JSON round-trip.',
  )
  final String activeModel;
  @override
  @JsonKey()
  final String ollamaEndpoint;
  @override
  @JsonKey()
  final ThemeModePreference theme;
  final Map<String, String> _outputFormatDefaults;
  @override
  @JsonKey()
  Map<String, String> get outputFormatDefaults {
    if (_outputFormatDefaults is EqualUnmodifiableMapView)
      return _outputFormatDefaults;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_outputFormatDefaults);
  }

  @override
  @JsonKey()
  final bool confirmAgentEdits;
  @override
  @JsonKey()
  final bool planEditsBeforeApply;
  @override
  @JsonKey()
  final String whisperBinaryPath;
  @override
  @JsonKey()
  final String whisperModelPath;
  @override
  @JsonKey()
  final String lastSeenVersion;

  @override
  String toString() {
    return 'AppSettings(activeProviderId: $activeProviderId, activeModel: $activeModel, ollamaEndpoint: $ollamaEndpoint, theme: $theme, outputFormatDefaults: $outputFormatDefaults, confirmAgentEdits: $confirmAgentEdits, planEditsBeforeApply: $planEditsBeforeApply, whisperBinaryPath: $whisperBinaryPath, whisperModelPath: $whisperModelPath, lastSeenVersion: $lastSeenVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppSettingsImpl &&
            (identical(other.activeProviderId, activeProviderId) ||
                other.activeProviderId == activeProviderId) &&
            (identical(other.activeModel, activeModel) ||
                other.activeModel == activeModel) &&
            (identical(other.ollamaEndpoint, ollamaEndpoint) ||
                other.ollamaEndpoint == ollamaEndpoint) &&
            (identical(other.theme, theme) || other.theme == theme) &&
            const DeepCollectionEquality().equals(
              other._outputFormatDefaults,
              _outputFormatDefaults,
            ) &&
            (identical(other.confirmAgentEdits, confirmAgentEdits) ||
                other.confirmAgentEdits == confirmAgentEdits) &&
            (identical(other.planEditsBeforeApply, planEditsBeforeApply) ||
                other.planEditsBeforeApply == planEditsBeforeApply) &&
            (identical(other.whisperBinaryPath, whisperBinaryPath) ||
                other.whisperBinaryPath == whisperBinaryPath) &&
            (identical(other.whisperModelPath, whisperModelPath) ||
                other.whisperModelPath == whisperModelPath) &&
            (identical(other.lastSeenVersion, lastSeenVersion) ||
                other.lastSeenVersion == lastSeenVersion));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    activeProviderId,
    activeModel,
    ollamaEndpoint,
    theme,
    const DeepCollectionEquality().hash(_outputFormatDefaults),
    confirmAgentEdits,
    planEditsBeforeApply,
    whisperBinaryPath,
    whisperModelPath,
    lastSeenVersion,
  );

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppSettingsImplCopyWith<_$AppSettingsImpl> get copyWith =>
      __$$AppSettingsImplCopyWithImpl<_$AppSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppSettingsImplToJson(this);
  }
}

abstract class _AppSettings implements AppSettings {
  const factory _AppSettings({
    final String activeProviderId,
    @Deprecated(
      'Unused since the provider-profile system; model selection '
      'lives in the provider profile (selectedModelId). Kept for the '
      'legacy-settings migration and JSON round-trip.',
    )
    final String activeModel,
    final String ollamaEndpoint,
    final ThemeModePreference theme,
    final Map<String, String> outputFormatDefaults,
    final bool confirmAgentEdits,
    final bool planEditsBeforeApply,
    final String whisperBinaryPath,
    final String whisperModelPath,
    final String lastSeenVersion,
  }) = _$AppSettingsImpl;

  factory _AppSettings.fromJson(Map<String, dynamic> json) =
      _$AppSettingsImpl.fromJson;

  @override
  String get activeProviderId;
  @override
  @Deprecated(
    'Unused since the provider-profile system; model selection '
    'lives in the provider profile (selectedModelId). Kept for the '
    'legacy-settings migration and JSON round-trip.',
  )
  String get activeModel;
  @override
  String get ollamaEndpoint;
  @override
  ThemeModePreference get theme;
  @override
  Map<String, String> get outputFormatDefaults;
  @override
  bool get confirmAgentEdits;
  @override
  bool get planEditsBeforeApply;
  @override
  String get whisperBinaryPath;
  @override
  String get whisperModelPath;
  @override
  String get lastSeenVersion;

  /// Create a copy of AppSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppSettingsImplCopyWith<_$AppSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
