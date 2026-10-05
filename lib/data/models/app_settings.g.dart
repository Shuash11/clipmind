// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => _AppSettings(
  activeProviderId: json['activeProviderId'] as String? ?? 'ollama',
  activeModel: json['activeModel'] as String? ?? '',
  ollamaEndpoint: json['ollamaEndpoint'] as String? ?? 'http://localhost:11434',
  theme:
      $enumDecodeNullable(_$ThemeModePreferenceEnumMap, json['theme']) ??
      ThemeModePreference.dark,
  outputFormatDefaults:
      (json['outputFormatDefaults'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  confirmAgentEdits: json['confirmAgentEdits'] as bool? ?? false,
  planEditsBeforeApply: json['planEditsBeforeApply'] as bool? ?? false,
  whisperBinaryPath: json['whisperBinaryPath'] as String? ?? '',
  whisperModelPath: json['whisperModelPath'] as String? ?? '',
  lastSeenVersion: json['lastSeenVersion'] as String? ?? '',
);

Map<String, dynamic> _$AppSettingsToJson(_AppSettings instance) =>
    <String, dynamic>{
      'activeProviderId': instance.activeProviderId,
      'activeModel': instance.activeModel,
      'ollamaEndpoint': instance.ollamaEndpoint,
      'theme': _$ThemeModePreferenceEnumMap[instance.theme]!,
      'outputFormatDefaults': instance.outputFormatDefaults,
      'confirmAgentEdits': instance.confirmAgentEdits,
      'planEditsBeforeApply': instance.planEditsBeforeApply,
      'whisperBinaryPath': instance.whisperBinaryPath,
      'whisperModelPath': instance.whisperModelPath,
      'lastSeenVersion': instance.lastSeenVersion,
    };

const _$ThemeModePreferenceEnumMap = {
  ThemeModePreference.dark: 'dark',
  ThemeModePreference.light: 'light',
  ThemeModePreference.system: 'system',
};
