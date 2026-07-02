// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppSettingsImpl _$$AppSettingsImplFromJson(Map<String, dynamic> json) =>
    _$AppSettingsImpl(
      activeProviderId: json['activeProviderId'] as String? ?? 'ollama',
      activeModel: json['activeModel'] as String? ?? '',
      ollamaEndpoint:
          json['ollamaEndpoint'] as String? ?? 'http://localhost:11434',
      theme:
          $enumDecodeNullable(_$ThemeModePreferenceEnumMap, json['theme']) ??
          ThemeModePreference.dark,
      outputFormatDefaults:
          (json['outputFormatDefaults'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$$AppSettingsImplToJson(_$AppSettingsImpl instance) =>
    <String, dynamic>{
      'activeProviderId': instance.activeProviderId,
      'activeModel': instance.activeModel,
      'ollamaEndpoint': instance.ollamaEndpoint,
      'theme': _$ThemeModePreferenceEnumMap[instance.theme]!,
      'outputFormatDefaults': instance.outputFormatDefaults,
    };

const _$ThemeModePreferenceEnumMap = {
  ThemeModePreference.dark: 'dark',
  ThemeModePreference.light: 'light',
  ThemeModePreference.system: 'system',
};
